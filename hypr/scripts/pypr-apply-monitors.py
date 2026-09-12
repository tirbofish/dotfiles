#!/usr/bin/env python3
"""Apply saved monitor layouts with Hyprland description selectors.

Connector-named rules (DP-3) and `preferred` both 0x0 a docked display
until relogin. Description rules only match once EDID is present, so this
waits, then sets an explicit mode from monitors.json.
"""
from __future__ import annotations

import fcntl
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
STATE_PATH = HOME / ".config/quickshell/lib/monitors.json"
LOCK_PATH = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "pypr-apply-monitors.lock"
LAPTOP = "eDP-1"
LAPTOP_PANEL = "LQ135P1JX51"
REAL_MODE = re.compile(r"^(\d{3,})x(\d{3,})(?:@([\d.]+))?")


def hypr_json(cmd: str):
    result = subprocess.run(
        ["hyprctl", "-j", cmd], capture_output=True, text=True, check=False
    )
    if result.returncode != 0 or not result.stdout.strip():
        return []
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return []


def load_configured() -> dict:
    try:
        raw = json.loads(STATE_PATH.read_text())
    except (OSError, json.JSONDecodeError):
        return {}
    configured = raw.get("configured") or {}
    return {
        key: spec
        for key, spec in configured.items()
        if key and not re.fullmatch(r"(eDP|DP|HDMI|DVI|WR)-\d+", key)
    }


def mode_is_real(mode: str | None) -> bool:
    if not mode or mode in {"preferred", "highres", "highrr", "maxwidth"}:
        return False
    match = REAL_MODE.match(mode)
    return bool(match and int(match.group(1)) >= 200 and int(match.group(2)) >= 200)


def first_real_mode(monitor: dict) -> str | None:
    for mode in monitor.get("availableModes") or []:
        cleaned = str(mode).replace("Hz", "")
        if mode_is_real(cleaned):
            return cleaned
    return None


def spec_for(monitor: dict, configured: dict) -> dict | None:
    description = str(monitor.get("description") or "")
    if not description:
        return None
    saved = configured.get(description)
    if not saved:
        for key, spec in configured.items():
            if key and key in description:
                saved = spec
                break
    mode = saved.get("mode") if saved else None
    if not mode_is_real(mode):
        mode = first_real_mode(monitor)
    if not mode_is_real(mode):
        return None
    position = (saved or {}).get("position") or "auto"
    if not re.fullmatch(r"-?\d+x-?\d+|auto(?:-(?:right|left|up|down))?", str(position)):
        position = "auto"
    scale = float((saved or {}).get("scale") or 1)
    if not 0.25 <= scale <= 8:
        scale = 1
    extra = {}
    if LAPTOP_PANEL in description:
        extra["bitdepth"] = 10
        extra["vrr"] = 1
    return {
        "output": "desc:" + description,
        "mode": mode,
        "position": position,
        "scale": scale,
        **extra,
    }


def lua_str(value) -> str:
    return str(value).replace("\\", "\\\\").replace('"', '\\"')


def apply_monitor(spec: dict) -> None:
    parts = [
        f'output = "{lua_str(spec["output"])}"',
        f'mode = "{lua_str(spec["mode"])}"',
        f'position = "{lua_str(spec["position"])}"',
        f'scale = {spec["scale"]}',
        "disabled = false",
    ]
    if spec.get("bitdepth") is not None:
        parts.append(f'bitdepth = {int(spec["bitdepth"])}')
    if spec.get("vrr") is not None:
        parts.append(f'vrr = {int(spec["vrr"])}')
    subprocess.run(
        ["hyprctl", "eval", "hl.monitor({ " + ", ".join(parts) + " })"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def connected(include_disabled: bool = True) -> list[dict]:
    monitors = hypr_json("monitors all" if include_disabled else "monitors")
    return [m for m in monitors if isinstance(m, dict)]


def is_zero(monitor: dict) -> bool:
    return int(monitor.get("width") or 0) < 200 or int(monitor.get("height") or 0) < 200


def wait_for_edid(configured: dict) -> list[dict]:
    latest = connected()
    for _ in range(10):
        ready = True
        for monitor in latest:
            if monitor.get("name") == LAPTOP:
                continue
            if not str(monitor.get("description") or ""):
                ready = False
                break
            if not spec_for(monitor, configured) and not first_real_mode(monitor):
                ready = False
                break
        if ready:
            return latest
        time.sleep(0.3)
        latest = connected()
    return latest


def apply_all() -> int:
    configured = load_configured()
    time.sleep(0.4)
    # Intel MST docks rename DP-4 -> DP-3 a second or two after the first
    # connect. Keep applying 0x0 outputs until a modeset sticks.
    for attempt in range(12):
        monitors = wait_for_edid(configured)
        specs = []
        pending_zero = False
        for monitor in monitors:
            if (
                monitor.get("disabled")
                and monitor.get("name") != LAPTOP
                and not is_zero(monitor)
            ):
                continue
            spec = spec_for(monitor, configured)
            if not spec:
                continue
            if attempt > 0 and not is_zero(monitor):
                continue
            if is_zero(monitor) and monitor.get("name") != LAPTOP:
                pending_zero = True
                spec["position"] = "auto-right"
            specs.append(spec)
        if len(specs) == 1:
            specs[0]["position"] = "0x0"
        for spec in specs:
            apply_monitor(spec)
        if not pending_zero:
            return 0
        time.sleep(0.8)
    return 0


def main() -> int:
    LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOCK_PATH.open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        stamp = time.time()
        lock.seek(0)
        lock.write(str(stamp))
        lock.truncate()
        lock.flush()
        time.sleep(0.35)
        current = LOCK_PATH.read_text().strip()
        if current != str(stamp):
            return 0
        return apply_all()


if __name__ == "__main__":
    sys.exit(main())
