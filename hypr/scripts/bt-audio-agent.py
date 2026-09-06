#!/usr/bin/env python3
"""Pair Bluetooth headsets and route PipeWire to their A2DP sink."""

import subprocess
import time

from gi.repository import Gio, GLib

BUS_NAME = "org.bluez"
AGENT_PATH = "/org/bluez/bt_audio_agent"
ADAPTER = "/org/bluez/hci0"


def run(cmd):
    return subprocess.run(cmd, check=False, capture_output=True, text=True)


def addr_of(path):
    return path.rsplit("/", 1)[-1].replace("_", ":")


def card_name(addr):
    return "bluez_card." + addr.replace(":", "_")


def is_audio_device(props):
    icon = str(props.get("Icon", "")).lower()
    klass = int(props.get("Class", 0) or 0)
    uuids = [str(u) for u in (props.get("UUIDs") or [])]
    return (
        "audio" in icon
        or "headset" in icon
        or (klass & 0x200000) != 0
        or "0000110b-0000-1000-8000-00805f9b34fb" in uuids
        or "0000111e-0000-1000-8000-00805f9b34fb" in uuids
    )


def get_props(bus, path):
    try:
        proxy = Gio.DBusProxy.new_sync(
            bus, Gio.DBusProxyFlags.NONE, None, BUS_NAME, path,
            "org.freedesktop.DBus.Properties", None,
        )
        variant = proxy.call_sync(
            "GetAll", GLib.Variant("(s)", ("org.bluez.Device1",)),
            Gio.DBusCallFlags.NONE, 4000, None,
        )
        return dict(variant.unpack()[0])
    except GLib.Error:
        return {}


def call(bus, path, iface, method, params=None, timeout=15000):
    proxy = Gio.DBusProxy.new_sync(
        bus, Gio.DBusProxyFlags.NONE, None, BUS_NAME, path, iface, None,
    )
    return proxy.call_sync(
        method, params, Gio.DBusCallFlags.NONE, timeout, None,
    )


def route_a2dp(addr):
    card = card_name(addr)
    for _ in range(25):
        cards = run(["pactl", "list", "cards", "short"]).stdout
        if card in cards:
            break
        time.sleep(0.4)
    else:
        return
    run(["pactl", "set-card-profile", card, "a2dp-sink"])
    sinks = run(["pactl", "list", "sinks", "short"]).stdout
    prefix = "bluez_output." + addr.replace(":", "_")
    sink = ""
    for line in sinks.splitlines():
        parts = line.split()
        if len(parts) > 1 and parts[1].startswith(prefix):
            sink = parts[1]
            break
    if not sink:
        return
    run(["pactl", "set-default-sink", sink])
    inputs = run(["pactl", "list", "sink-inputs", "short"]).stdout
    for line in inputs.splitlines():
        sid = line.split()[0] if line.split() else ""
        if sid:
            run(["pactl", "move-sink-input", sid, sink])


def handle_device(bus, path):
    props = get_props(bus, path)
    if not props or not is_audio_device(props):
        return
    addr = props.get("Address") or addr_of(path)
    if props.get("Connected") and not props.get("Paired"):
        try:
            call(bus, path, "org.bluez.Device1", "Disconnect", timeout=8000)
        except GLib.Error:
            pass
        time.sleep(0.6)
        props = get_props(bus, path)
    if not props.get("Paired"):
        try:
            call(bus, path, "org.bluez.Device1", "Pair", timeout=30000)
        except GLib.Error:
            return
    try:
        call(
            bus, path, "org.freedesktop.DBus.Properties", "Set",
            GLib.Variant("(ssv)", ("org.bluez.Device1", "Trusted", GLib.Variant("b", True))),
        )
    except GLib.Error:
        pass
    try:
        call(bus, path, "org.bluez.Device1", "Connect", timeout=20000)
    except GLib.Error:
        pass
    GLib.timeout_add(800, lambda: (route_a2dp(addr), False)[1])

class Agent:
    def __init__(self, bus):
        self.bus = bus
        node = Gio.DBusNodeInfo.new_for_xml("""
        <node>
          <interface name="org.bluez.Agent1">
            <method name="Release"/>
            <method name="RequestPinCode"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
            <method name="DisplayPinCode"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
            <method name="RequestPasskey"><arg type="o" direction="in"/><arg type="u" direction="out"/></method>
            <method name="DisplayPasskey"><arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/></method>
            <method name="RequestConfirmation"><arg type="o" direction="in"/><arg type="u" direction="in"/></method>
            <method name="RequestAuthorization"><arg type="o" direction="in"/></method>
            <method name="AuthorizeService"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
            <method name="Cancel"/>
          </interface>
        </node>
        """)
        bus.register_object(AGENT_PATH, node.interfaces[0], self.on_method, None, None)

    def on_method(self, _conn, _sender, _path, _iface, method, params, invocation):
        if method == "RequestPinCode":
            invocation.return_value(GLib.Variant("(s)", ("0000",)))
        elif method == "RequestPasskey":
            invocation.return_value(GLib.Variant("(u)", (0,)))
        elif method in ("RequestConfirmation", "RequestAuthorization", "AuthorizeService",
                        "DisplayPinCode", "DisplayPasskey", "Release", "Cancel"):
            invocation.return_value(None)
        else:
            invocation.return_error_literal("org.bluez.Error.Rejected", 0, "rejected")


def on_signal(_conn, _sender, _path, iface, signal, params, bus):
    if iface == "org.freedesktop.DBus.ObjectManager" and signal == "InterfacesAdded":
        path, ifaces = params.unpack()
        if "org.bluez.Device1" in ifaces:
            GLib.timeout_add(400, lambda: (handle_device(bus, path), False)[1])
    elif iface == "org.freedesktop.DBus.Properties" and signal == "PropertiesChanged":
        changed_iface, changed, _ = params.unpack()
        if changed_iface == "org.bluez.Device1" and changed.get("Connected") is True:
            GLib.timeout_add(400, lambda: (handle_device(bus, _path), False)[1])


def main():
    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    Agent(bus)
    mgr = Gio.DBusProxy.new_sync(
        bus, Gio.DBusProxyFlags.NONE, None, BUS_NAME, "/org/bluez",
        "org.bluez.AgentManager1", None,
    )
    mgr.call_sync(
        "RegisterAgent",
        GLib.Variant("(os)", (AGENT_PATH, "NoInputNoOutput")),
        Gio.DBusCallFlags.NONE, 5000, None,
    )
    mgr.call_sync(
        "RequestDefaultAgent",
        GLib.Variant("(o)", (AGENT_PATH,)),
        Gio.DBusCallFlags.NONE, 5000, None,
    )
    bus.signal_subscribe(
        BUS_NAME, None, None, None, None, Gio.DBusSignalFlags.NONE, on_signal, bus,
    )
    for path in (
        Gio.DBusProxy.new_sync(
            bus, Gio.DBusProxyFlags.NONE, None, BUS_NAME, "/",
            "org.freedesktop.DBus.ObjectManager", None,
        ).call_sync("GetManagedObjects", None, Gio.DBusCallFlags.NONE, 5000, None)
        .unpack()[0]
    ):
        if path.startswith("/org/bluez/") and path.count("/") >= 4:
            props = get_props(bus, path)
            if props.get("Connected"):
                handle_device(bus, path)
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
