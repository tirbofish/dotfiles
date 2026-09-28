#!/usr/bin/env python3
"""Persist PipeWire output per connected display.

Intel HDA exposes analog speakers and HDMI as mutually exclusive card
profiles. WirePlumber remembers the HDMI sink name, but does not switch
the profile when the display returns, so output stays on the laptop
speakers. This maps a chosen sink/profile to a monitor description and
applies it on plug/unplug.
"""
from __future__ import annotations

import fcntl
import json
import os
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
STATE_PATH = HOME / ".config/quickshell/lib/audio-outputs.json"
WP_NODES = HOME / ".local/state/wireplumber/default-nodes"
LOCK_PATH = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "display-audio.lock"
LAPTOP = "eDP-1"
LAPTOP_PANEL = "LQ135P1JX51"


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, capture_output=True, text=True, check=False)


def pactl_json(args: list[str]):
    result = run(["pactl", "-f", "json", *args])
    if result.returncode != 0 or not result.stdout.strip():
        return []
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return []


def hypr_monitors() -> list[dict]:
    result = run(["hyprctl", "-j", "monitors"])
    if result.returncode != 0 or not result.stdout.strip():
        return []
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        return []
    return [m for m in data if isinstance(m, dict)]


def load_state() -> dict:
    try:
        raw = json.loads(STATE_PATH.read_text())
    except (OSError, json.JSONDecodeError):
        return {"byDisplay": {}, "undocked": None}
    if not isinstance(raw, dict):
        return {"byDisplay": {}, "undocked": None}
    by_display = raw.get("byDisplay") or {}
    if not isinstance(by_display, dict):
        by_display = {}
    undocked = raw.get("undocked")
    if undocked is not None and not isinstance(undocked, dict):
        undocked = None
    return {"byDisplay": by_display, "undocked": undocked}


def save_state(state: dict) -> None:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE_PATH.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(state, indent=2) + "\n")
    tmp.replace(STATE_PATH)


def default_sink_name() -> str:
    return (run(["pactl", "get-default-sink"]).stdout or "").strip()


def is_bluetooth(name: str | None) -> bool:
    n = str(name or "")
    return n.startswith("bluez_") or n.startswith("bluez.")


def external_monitors(monitors: list[dict]) -> list[dict]:
    out = []
    for monitor in monitors:
        name = str(monitor.get("name") or "")
        desc = str(monitor.get("description") or "")
        if name == LAPTOP or LAPTOP_PANEL in desc:
            continue
        if desc:
            out.append(monitor)
    return out


def cards() -> list[dict]:
    data = pactl_json(["list", "cards"])
    return [c for c in data if isinstance(c, dict)]


def sinks() -> list[dict]:
    data = pactl_json(["list", "sinks"])
    return [s for s in data if isinstance(s, dict)]


def sink_named(name: str) -> dict | None:
    for sink in sinks():
        if sink.get("name") == name:
            return sink
    return None


def card_named(name: str) -> dict | None:
    for card in cards():
        if card.get("name") == name:
            return card
    return None


def props(obj: dict) -> dict:
    return obj.get("properties") or {}


def port_product(port: dict) -> str:
    return str((port.get("properties") or {}).get("device.product.name") or "")


def port_available(port: dict) -> bool:
    avail = str(port.get("availability") or "").lower()
    if avail in {"not available", "no"}:
        return False
    flag = port.get("available")
    if flag is False:
        return False
    return True


def match_display(product: str, monitors: list[dict]) -> str | None:
    needle = product.strip().lower()
    if not needle:
        return None
    best = None
    for monitor in monitors:
        desc = str(monitor.get("description") or "")
        if needle in desc.lower():
            if best is None or len(desc) < len(best):
                best = desc
    return best


def profile_available(card: dict, name: str) -> bool:
    info = (card.get("profiles") or {}).get(name)
    if info is None:
        return False
    if isinstance(info, dict) and info.get("available") is False:
        return False
    return True


def prefer_profile(card: dict, candidates: list[str]) -> str | None:
    for name in candidates:
        if profile_available(card, name):
            return name
    return None


def hdmi_profile_for_port(card: dict, port_name: str) -> str | None:
    extra = ""
    if port_name.startswith("hdmi-output-") and port_name != "hdmi-output-0":
        try:
            idx = int(port_name.rsplit("-", 1)[-1])
        except ValueError:
            idx = 0
        if idx > 0:
            extra = f"-extra{idx}"
    base = f"hdmi-stereo{extra}"
    return prefer_profile(
        card,
        [f"output:{base}+input:analog-stereo", f"output:{base}"],
    )


def analog_profile(card: dict) -> str | None:
    return prefer_profile(
        card,
        ["output:analog-stereo+input:analog-stereo", "output:analog-stereo"],
    )


def profile_for_sink(card: dict, sink_name: str, saved: str | None = None) -> str | None:
    if saved and profile_available(card, saved):
        return saved
    if "hdmi-stereo-extra" in sink_name:
        extra = sink_name.split("hdmi-stereo-extra", 1)[-1].split(".", 1)[0]
        base = f"hdmi-stereo-extra{extra}"
        return prefer_profile(
            card, [f"output:{base}+input:analog-stereo", f"output:{base}"]
        )
    if ".hdmi-stereo" in sink_name:
        return prefer_profile(
            card,
            ["output:hdmi-stereo+input:analog-stereo", "output:hdmi-stereo"],
        )
    if "iec958" in sink_name:
        return prefer_profile(
            card,
            [
                "output:iec958-stereo+input:analog-stereo",
                "output:iec958-stereo",
            ],
        )
    if "analog-stereo" in sink_name:
        return analog_profile(card)
    active = card.get("active_profile")
    if isinstance(active, str) and active:
        return active
    return None


def target_from_sink(sink_name: str) -> dict | None:
    sink = sink_named(sink_name)
    if not sink:
        return {"sink": sink_name}
    card_name = str(props(sink).get("device.name") or "")
    card = card_named(card_name) if card_name else None
    profile = None
    if card:
        profile = profile_for_sink(card, sink_name, card.get("active_profile"))
    return {
        "sink": sink_name,
        "card": card_name or None,
        "profile": profile,
    }


def hdmi_target_for_display(description: str) -> dict | None:
    for card in cards():
        for port_name, port in (card.get("ports") or {}).items():
            if not str(port_name).startswith("hdmi-"):
                continue
            if not port_available(port):
                continue
            product = port_product(port)
            if not product or product.lower() not in description.lower():
                continue
            profile = hdmi_profile_for_port(card, str(port_name))
            if not profile:
                continue
            card_name = str(card.get("name") or "")
            suffix = profile.split("+", 1)[0].removeprefix("output:")
            return {
                "sink": f"{card_name.replace('alsa_card.', 'alsa_output.', 1)}.{suffix}",
                "card": card_name,
                "profile": profile,
            }
    return None


def configured_sinks() -> list[str]:
    try:
        text = WP_NODES.read_text()
    except OSError:
        return []
    found: dict[int, str] = {}
    primary = ""
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("default.configured.audio.sink="):
            primary = line.split("=", 1)[1].strip()
        elif line.startswith("default.configured.audio.sink."):
            key, _, value = line.partition("=")
            try:
                idx = int(key.rsplit(".", 1)[-1])
            except ValueError:
                continue
            found[idx] = value.strip()
    names = [primary] if primary else []
    for idx in sorted(found):
        if found[idx] and found[idx] not in names:
            names.append(found[idx])
    return names


def current_target() -> dict | None:
    name = default_sink_name()
    if not name or is_bluetooth(name):
        return None
    return target_from_sink(name)


def apply_target(target: dict) -> bool:
    sink = str(target.get("sink") or "")
    if not sink or is_bluetooth(sink):
        return False
    card_name = str(target.get("card") or "")
    profile = str(target.get("profile") or "")
    if card_name and profile:
        card = card_named(card_name)
        if card and card.get("active_profile") != profile and profile_available(card, profile):
            run(["pactl", "set-card-profile", card_name, profile])
            time.sleep(0.25)
    if not sink_named(sink):
        return False
    if default_sink_name() != sink:
        run(["pactl", "set-default-sink", sink])
    for line in (run(["pactl", "list", "short", "sink-inputs"]).stdout or "").splitlines():
        sid = line.split()[0] if line.split() else ""
        if sid:
            run(["pactl", "move-sink-input", sid, sink])
    return default_sink_name() == sink


def is_display_sink(name: str) -> bool:
    return "hdmi" in name or "iec958" in name or name.startswith("alsa_output.usb-")


def pick_mapped(mapped: list[dict]) -> dict:
    for target in mapped:
        if is_display_sink(str(target.get("sink") or "")):
            return target
    return mapped[0]


def analog_fallback() -> dict | None:
    for card in cards():
        form = str(props(card).get("device.form_factor") or "")
        name = str(card.get("name") or "")
        if form != "internal" and "pci-" not in name:
            continue
        profile = analog_profile(card)
        if not profile:
            continue
        return {
            "sink": name.replace("alsa_card.", "alsa_output.", 1) + ".analog-stereo",
            "card": name,
            "profile": profile,
        }
    return None


def pick_restore_target(state: dict, monitors: list[dict]) -> dict | None:
    externals = external_monitors(monitors)
    if not externals:
        return state.get("undocked") or analog_fallback()
    mapped = []
    for monitor in externals:
        desc = str(monitor.get("description") or "")
        saved = (state.get("byDisplay") or {}).get(desc)
        if isinstance(saved, dict) and saved.get("sink"):
            mapped.append(saved)
    if mapped:
        return pick_mapped(mapped)
    for name in configured_sinks():
        if is_bluetooth(name) or not name or not is_display_sink(name):
            continue
        for monitor in externals:
            hdmi = hdmi_target_for_display(str(monitor.get("description") or ""))
            if hdmi and (
                hdmi.get("sink") == name
                or str(hdmi.get("sink") or "").endswith(name.rsplit(".", 1)[-1])
            ):
                return hdmi
        target = target_from_sink(name)
        if target:
            return target
    return None


def remember(state: dict, target: dict, monitors: list[dict]) -> dict:
    sink = str(target.get("sink") or "")
    externals = external_monitors(monitors)
    if not externals:
        state["undocked"] = target
        return state
    hdmi_desc = None
    for card in cards():
        for port in (card.get("ports") or {}).values():
            if not port_available(port):
                continue
            product = port_product(port)
            desc = match_display(product, externals)
            if desc and "hdmi" in sink:
                hdmi_desc = desc
                break
        if hdmi_desc:
            break
    keys = [hdmi_desc] if hdmi_desc else [str(m.get("description")) for m in externals]
    by_display = state.setdefault("byDisplay", {})
    for key in keys:
        if key:
            by_display[key] = target
    analogish = "analog-stereo" in sink or "Enhanced" in sink
    if analogish:
        state["undocked"] = target
    elif not state.get("undocked"):
        state["undocked"] = analog_fallback()
    return state


def cmd_save() -> int:
    target = current_target()
    if not target:
        return 0
    state = load_state()
    save_state(remember(state, target, hypr_monitors()))
    return 0


def cmd_restore() -> int:
    time.sleep(0.35)
    last = None
    for _ in range(16):
        name = default_sink_name()
        if is_bluetooth(name):
            return 0
        state = load_state()
        target = pick_restore_target(state, hypr_monitors())
        if not target:
            return 0
        last = target
        if apply_target(target):
            save_state(remember(state, target, hypr_monitors()))
            return 0
        time.sleep(0.45)
    if last:
        apply_target(last)
    return 0


def with_lock(fn):
    LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOCK_PATH.open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        return fn()


def main(argv: list[str]) -> int:
    action = argv[1] if len(argv) > 1 else "restore"
    if action == "save":
        return with_lock(cmd_save)
    if action == "restore":
        return with_lock(cmd_restore)
    print("Usage: display-audio.py {save|restore}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
