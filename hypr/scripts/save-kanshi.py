#!/usr/bin/env python3
"""Persist a settings-panel edit and apply it through pyprland."""
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import tomllib


HOME = Path.home()
PYPR_CONFIG = HOME / ".config/pypr/config.toml"
APPLY = HOME / ".config/hypr/scripts/pypr-apply-monitors.py"
LAPTOP = "eDP-1"


def parse_mode(mode: str) -> tuple[str, float | None]:
    match = re.fullmatch(
        r"(?:preferred|([1-9]\d{2,})x([1-9]\d{2,})(?:@([\d.]+)(?:Hz)?)?)",
        mode,
    )
    if not match or not match.group(1):
        raise ValueError("Invalid mode")
    rate = float(match.group(3)) if match.group(3) else None
    return f"{match.group(1)}x{match.group(2)}", rate


def relative_rule(position: str) -> str:
    match = re.fullmatch(r"(-?\d+)x(-?\d+)", position)
    if not match:
        return "rightOf"
    x, y = int(match.group(1)), int(match.group(2))
    if abs(x) >= abs(y):
        return "rightOf" if x >= 0 else "leftOf"
    return "bottomOf" if y >= 0 else "topOf"


def dumps(config: dict) -> str:
    pypr = config.get("pyprland", {})
    monitors = config.get("monitors", {})
    placement = monitors.get("placement") or {}
    lines = [
        "# Pyprland owns hotplug. Do not name DP-* or use preferred; both 0x0",
        "# a docked display until relogin. The apply script matches desc: after EDID.",
        "# Saved mode/position/scale live in ~/.config/quickshell/lib/monitors.json.",
        "",
        "[pyprland]",
        "plugins = [" + ", ".join(json.dumps(p) for p in pypr.get("plugins", ["monitors"])) + "]",
        "",
        "[monitors]",
    ]
    for key in ("startup_relayout", "relayout_on_config_change", "new_monitor_delay", "hotplug_command", "unknown"):
        if key not in monitors:
            continue
        value = monitors[key]
        if isinstance(value, bool):
            lines.append(f"{key} = {'true' if value else 'false'}")
        elif isinstance(value, (int, float)) and not isinstance(value, bool):
            lines.append(f"{key} = {value}")
        else:
            lines.append(f"{key} = {json.dumps(value)}")
    for name, rules in placement.items():
        lines.append("")
        lines.append(f"[monitors.placement.{json.dumps(name)}]")
        for rule, value in rules.items():
            if isinstance(value, bool):
                lines.append(f"{rule} = {'true' if value else 'false'}")
            elif isinstance(value, (int, float)) and not isinstance(value, bool):
                lines.append(f"{rule} = {value}")
            elif isinstance(value, list):
                lines.append(f"{rule} = [{', '.join(json.dumps(v) for v in value)}]")
            else:
                lines.append(f"{rule} = {json.dumps(value)}")
    return "\n".join(lines) + "\n"


def placement_key(output: str) -> str:
    if output == LAPTOP:
        return "LQ135P1JX51"
    return output


def drop_direction(rules: dict) -> dict:
    keep = {}
    for key, value in rules.items():
        lowered = key.lower().replace("_", "")
        if any(lowered.startswith(d) for d in ("left", "right", "top", "bottom")):
            continue
        keep[key] = value
    return keep


def update_pypr(config: dict, output: str, spec: dict) -> dict:
    mode = spec["mode"]
    scale = float(spec["scale"])
    position = spec["position"]
    resolution, rate = parse_mode(mode)
    if not math.isfinite(scale) or not 0.25 <= scale <= 8:
        raise ValueError("Invalid scale")
    if not re.fullmatch(r"-?\d+x-?\d+", position):
        raise ValueError("Invalid position")
    monitors = config.setdefault("monitors", {})
    placement = monitors.setdefault("placement", {})
    key = placement_key(output)
    current = dict(placement.get(key) or {})
    if key != "LQ135P1JX51":
        current = drop_direction(current)
        current[relative_rule(position)] = "LQ135P1JX51"
    current["resolution"] = resolution
    if rate is not None:
        current["rate"] = rate
    current["scale"] = scale
    placement[key] = current
    return config


def default_config() -> dict:
    return {
        "pyprland": {"plugins": ["monitors"]},
        "monitors": {
            "startup_relayout": False,
            "relayout_on_config_change": False,
            "new_monitor_delay": 2.0,
            "hotplug_command": str(APPLY),
            "unknown": str(APPLY),
            "placement": {},
        },
    }


def load_config() -> dict:
    if not PYPR_CONFIG.exists():
        return default_config()
    with PYPR_CONFIG.open("rb") as fh:
        loaded = tomllib.load(fh)
    merged = default_config()
    merged["pyprland"].update(loaded.get("pyprland") or {})
    monitors = loaded.get("monitors") or {}
    merged["monitors"].update({k: v for k, v in monitors.items() if k != "placement"})
    merged["monitors"]["placement"] = dict(monitors.get("placement") or {})
    return merged


def apply_now() -> None:
    subprocess.run(["python3", str(APPLY)], check=False)
    subprocess.run(
        ["systemctl", "--user", "kill", "-s", "HUP", "pyprland.service"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


if __name__ == "__main__":
    if sys.argv[1:] == ["--test"]:
        spec = dict(mode="2256x1504@60", position="0x0", scale=1.5)
        result = update_pypr(default_config(), "eDP-1", spec)
        laptop = result["monitors"]["placement"]["LQ135P1JX51"]
        assert laptop["resolution"] == "2256x1504" and laptop["scale"] == 1.5
        result = update_pypr(result, "LG ULTRAWIDE", dict(mode="2560x1080@59.978", position="-387x100", scale=1))
        lg = result["monitors"]["placement"]["LG ULTRAWIDE"]
        assert lg["resolution"] == "2560x1080" and "Of" in "".join(lg)
        dumped = dumps(result)
        assert "[monitors.placement.\"LQ135P1JX51\"]" in dumped
        try:
            update_pypr(result, "eDP-1", dict(spec, scale=float("nan")))
        except ValueError:
            pass
        else:
            raise AssertionError("Invalid scale accepted")
        print("pyprland settings check passed")
    else:
        path = PYPR_CONFIG
        path.parent.mkdir(parents=True, exist_ok=True)
        content = dumps(update_pypr(load_config(), sys.argv[1], json.loads(sys.argv[2])))
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as fh:
            fh.write(content)
            temporary = fh.name
        os.replace(temporary, path)
        apply_now()
