#!/usr/bin/env python3
"""Keep playing music awake; pause or mute it when its audio route changes.

The sleep/lid inhibitor deliberately excludes idle, so locking and DPMS still
work. Use `can-suspend` in hypridle conditions and `suspend` as its action.
"""

import json
import os
import re
import signal
import subprocess
import sys
import time
from dataclasses import dataclass

import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib, GLibUnix

PLAYER_IFACE = "org.mpris.MediaPlayer2.Player"
PLAYER_PATH = "/org/mpris/MediaPlayer2"
PLAYER_PREFIX = "org.mpris.MediaPlayer2."


def run(*args):
    return subprocess.run(args, capture_output=True, text=True, timeout=3,
                          check=False, env={**os.environ, "LC_ALL": "C"})


def pactl_json(kind):
    result = run("pactl", "--format=json", "list", kind)
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return json.loads(result.stdout)


@dataclass
class Audio:
    default: str
    sinks: dict
    streams: list

    def route(self, sink):
        if sink is None:
            return None
        return (sink["name"], sink.get("active_port"))

    @property
    def default_route(self):
        return self.route(next((s for s in self.sinks.values()
                                if s["name"] == self.default), None))

    @property
    def stream_routes(self):
        return {s["index"]: self.route(self.sinks.get(s["sink"]))
                for s in self.streams}

    def audible(self, stream):
        sink = self.sinks.get(stream["sink"], {})
        return not (stream.get("corked", True) or stream.get("mute", False)
                    or sink.get("mute", False))

    @property
    def music_playing(self):
        return any(self.audible(s) and s.get("properties", {}).get("media.role")
                   == "music" for s in self.streams)


def read_audio():
    result = run("pactl", "get-default-sink")
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return Audio(result.stdout.strip(), {s["index"]: s for s in pactl_json("sinks")},
                 pactl_json("sink-inputs"))


def read_players(bus):
    players = {}
    for name in bus.list_names():
        if not name.startswith(PLAYER_PREFIX):
            continue
        try:
            obj = bus.get_object(name, PLAYER_PATH, introspect=False)
            props = dbus.Interface(obj, "org.freedesktop.DBus.Properties")
            status = str(props.Get(PLAYER_IFACE, "PlaybackStatus", timeout=1))
            identity = str(props.Get("org.mpris.MediaPlayer2", "Identity", timeout=1))
            players[str(name)] = {"status": status, "identity": identity, "object": obj}
        except dbus.DBusException as error:
            # Disappearing players are normal. A hung player is not safe to
            # treat as stopped: retain an unknown state until it responds.
            if error.get_dbus_name() not in ("org.freedesktop.DBus.Error.ServiceUnknown",
                                            "org.freedesktop.DBus.Error.NameHasNoOwner",
                                            "org.freedesktop.DBus.Error.UnknownObject"):
                players[str(name)] = {"status": "Unknown", "identity": str(name),
                                      "object": None}
    return players


def playback_active(players, audio):
    return any(p["status"] in ("Playing", "Unknown") for p in players.values()) or audio.music_playing


def route_changed(previous, current):
    if previous is None:
        return False
    if previous.default_route != current.default_route:
        return True
    before, after = previous.stream_routes, current.stream_routes
    if any(before[index] != after[index] for index in before.keys() & after.keys()):
        return True
    # A disconnected non-default output can remove its stream altogether.
    routes = {current.route(s) for s in current.sinks.values()}
    return any(previous.audible(s) and before[s["index"]] not in routes
               for s in previous.streams)


def normalized(value):
    return re.sub(r"[^a-z0-9]", "", value.casefold())


class Guard:
    def __init__(self):
        self.bus = dbus.SessionBus()
        self.system_bus = dbus.SystemBus()
        self.previous = None
        self.inhibitor = None
        self.pending = False
        self.subscriber = None
        self.loop = GLib.MainLoop()
        self.bus.add_signal_receiver(self.player_changed, signal_name="PropertiesChanged",
                                     dbus_interface="org.freedesktop.DBus.Properties",
                                     path=PLAYER_PATH)
        self.bus.add_signal_receiver(self.owner_changed, signal_name="NameOwnerChanged",
                                     dbus_interface="org.freedesktop.DBus")

    def player_changed(self, interface, changed, invalidated):
        if interface == PLAYER_IFACE and ("PlaybackStatus" in changed
                                          or "PlaybackStatus" in invalidated):
            self.schedule()

    def owner_changed(self, name, old, new):
        if str(name).startswith(PLAYER_PREFIX):
            self.schedule()

    def schedule(self):
        if not self.pending:
            self.pending = True
            GLib.idle_add(self.scheduled_refresh)

    def scheduled_refresh(self):
        self.pending = False
        self.refresh()
        return GLib.SOURCE_REMOVE

    def inhibit(self, active):
        if active and self.inhibitor is None:
            manager = dbus.Interface(self.system_bus.get_object("org.freedesktop.login1",
                                     "/org/freedesktop/login1", introspect=False),
                                     "org.freedesktop.login1.Manager")
            self.inhibitor = manager.Inhibit("sleep:handle-lid-switch", "Hyprland music guard",
                                "Music is playing; keep audio running with the screen off",
                                "block", timeout=3).take()
            os.set_inheritable(self.inhibitor, False)
            print("Music playing: suspend and lid sleep inhibited", flush=True)
        elif not active and self.inhibitor is not None:
            os.close(self.inhibitor)
            self.inhibitor = None
            print("Music stopped/paused: normal sleep restored", flush=True)

    def pause_on_change(self, players, audio):
        muted = []
        # Silence streams first to limit sound escaping during device fallback.
        # Communications streams are not music and are left alone.
        for stream in audio.streams:
            if (audio.audible(stream) and stream.get("properties", {}).get("media.role")
                    not in ("phone", "communication")):
                if run("pactl", "set-sink-input-mute", str(stream["index"]), "1").returncode == 0:
                    muted.append(stream)
        paused = set()
        for name, player in players.items():
            if player["status"] == "Playing" and player["object"] is not None:
                try:
                    dbus.Interface(player["object"], PLAYER_IFACE).Pause(timeout=1)
                    paused.add(name)
                except dbus.DBusException:
                    pass
        if muted or paused:
            print("Audio output changed: pausing playback (muting unsupported streams)", flush=True)
            GLib.timeout_add(250, self.finish_pause, paused, muted)

    def finish_pause(self, paused, muted):
        players = read_players(self.bus)
        identities = set()
        for name in paused:
            player = players.get(name)
            if player and player["status"] in ("Paused", "Stopped"):
                identities.update((normalized(player["identity"]),
                                   normalized(name.removeprefix(PLAYER_PREFIX).split(".")[0])))
        fallback = False
        for stream in muted:
            props = stream.get("properties", {})
            if any(normalized(str(props.get(key, ""))) in identities
                   for key in ("application.name", "application.process.binary")):
                # A confirmed pause is sufficient. Restore the stream's mute
                # state so pressing Play later works normally.
                run("pactl", "set-sink-input-mute", str(stream["index"]), "0")
            else:
                fallback = True
        message = "Playback paused. Press Play when you're ready."
        if fallback:
            message += " Audio without pause controls was muted; unmute it in the sound mixer."
        subprocess.Popen(["notify-send", "-a", "Music guard", "Audio output changed", message],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.schedule()
        return GLib.SOURCE_REMOVE

    def refresh(self):
        try:
            players = read_players(self.bus)
            audio = read_audio()
            changed = route_changed(self.previous, audio)
            self.previous = audio
            if changed:
                self.pause_on_change(players, audio)
                players = read_players(self.bus)
                audio = read_audio()
            self.inhibit(playback_active(players, audio))
        except (dbus.DBusException, RuntimeError, subprocess.TimeoutExpired, ValueError) as error:
            # Preserve any existing inhibitor during a temporary audio failure.
            print(f"Music guard will retry: {error}", file=sys.stderr, flush=True)
        return GLib.SOURCE_CONTINUE

    def audio_event(self, fd, condition):
        data = os.read(fd, 65536)
        if not data:
            # Restart through systemd if PipeWire or its subscription exits.
            self.loop.quit()
            return GLib.SOURCE_REMOVE
        if any(kind in data for kind in (b" on sink ", b" on sink-input ", b" on server ", b" on card ")):
            self.schedule()
        return GLib.SOURCE_CONTINUE

    def start(self):
        self.subscriber = subprocess.Popen(["pactl", "subscribe"], stdout=subprocess.PIPE,
                                            env={**os.environ, "LC_ALL": "C"})
        GLib.io_add_watch(self.subscriber.stdout.fileno(), GLib.IO_IN | GLib.IO_HUP,
                         self.audio_event)
        GLib.timeout_add_seconds(5, self.refresh)
        def stop(*args):
            self.loop.quit()
            return GLib.SOURCE_REMOVE

        GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, stop)
        GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, stop)
        try:
            self.refresh()
            self.loop.run()
        finally:
            self.inhibit(False)
            self.subscriber.terminate()
            self.subscriber.wait(timeout=3)


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "watch"
    if action not in ("watch", "can-suspend", "suspend", "sleep", "status"):
        print("Usage: music-guard.py {watch|can-suspend|suspend|sleep|status}", file=sys.stderr)
        return 2
    DBusGMainLoop(set_as_default=True)
    if action == "watch":
        Guard().start()
        return 0
    try:
        players = read_players(dbus.SessionBus())
        audio = read_audio()
        active = playback_active(players, audio)
    except (dbus.DBusException, RuntimeError, subprocess.TimeoutExpired, ValueError) as error:
        print(f"Cannot verify playback; skipping idle suspend: {error}", file=sys.stderr)
        return 1
    if action == "status":
        print(json.dumps({"playing": active, "output": audio.default_route,
                          "players": {name.removeprefix(PLAYER_PREFIX): p["status"]
                                      for name, p in players.items()}}, indent=2))
        return 0
    if active:
        if action == "sleep":
            # The power menu's Suspend action becomes screen sleep during
            # playback. A true suspend cannot keep user-space audio running.
            run("loginctl", "lock-session")
            for _ in range(40):
                if run("pgrep", "-u", str(os.getuid()), "-x", "hyprlock").returncode == 0:
                    break
                time.sleep(0.05)
            return run("hyprctl", "dispatch", 'hl.dsp.dpms({action = "off"})').returncode
        return 1
    if action in ("suspend", "sleep"):
        return subprocess.run(["systemctl", "--check-inhibitors=yes", "suspend"],
                              check=False).returncode
    return 0


if __name__ == "__main__":
    sys.exit(main())
