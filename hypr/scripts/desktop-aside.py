#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import time

PEEK_FRAC = 0.02
MIN_PEEK = 12


def run(args):
    subprocess.run(args, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def hypr_json(cmd):
    return json.loads(subprocess.check_output(["hyprctl", "-j", cmd]))


def batch(exprs):
    if not exprs:
        return
    run(["hyprctl", "-q", "--batch", "; ".join("dispatch " + e for e in exprs)])


def selector(address):
    return f"address:{address}"


def layout_mon(mon):
    scale = mon.get("scale") or 1
    if scale <= 0:
        scale = 1
    return {
        "x": int(mon.get("x") or 0),
        "y": int(mon.get("y") or 0),
        "w": int((mon.get("width") or 0) / scale),
        "h": int((mon.get("height") or 0) / scale),
    }


def peek_px(length):
    return max(MIN_PEEK, int(round(length * PEEK_FRAC)))


def work_rect(mon, reserved):
    # hyprctl reserved is [left, top, right, bottom] in layout pixels.
    left = int((reserved or [0, 0, 0, 0])[0] or 0)
    top = int((reserved or [0, 0, 0, 0])[1] or 0)
    right = int((reserved or [0, 0, 0, 0])[2] or 0)
    bottom = int((reserved or [0, 0, 0, 0])[3] or 0)
    return {
        "x": mon["x"] + left,
        "y": mon["y"] + top,
        "w": mon["w"] - left - right,
        "h": mon["h"] - top - bottom,
    }


def nearest_offscreen(at, size, work):
    cx = at[0] + size[0] / 2
    cy = at[1] + size[1] / 2
    left = cx - work["x"]
    right = (work["x"] + work["w"]) - cx
    top = cy - work["y"]
    bottom = (work["y"] + work["h"]) - cy
    edge = min(
        (("left", left), ("right", right), ("up", top), ("down", bottom)),
        key=lambda item: item[1],
    )[0]
    x, y = int(at[0]), int(at[1])
    peek_w = peek_px(size[0])
    peek_h = peek_px(size[1])
    if edge == "left":
        x = work["x"] - int(size[0]) + peek_w
    elif edge == "right":
        x = work["x"] + work["w"] - peek_w
    elif edge == "up":
        y = work["y"] - int(size[1]) + peek_h
    else:
        y = work["y"] + work["h"] - peek_h
    return x, y


def show(state_path):
    if os.path.exists(state_path):
        return
    raw_mons = hypr_json("monitors")
    monitors = {m["id"]: layout_mon(m) for m in raw_mons}
    works = {m["id"]: work_rect(layout_mon(m), m.get("reserved")) for m in raw_mons}
    active = {m.get("activeWorkspace", {}).get("id") for m in raw_mons}
    saved = []
    for win in hypr_json("clients"):
        if not win.get("mapped") or win.get("pinned") or not win.get("visible"):
            continue
        if win.get("workspace", {}).get("id") not in active:
            continue
        mon = monitors.get(win.get("monitor"))
        work = works.get(win.get("monitor"))
        size = win.get("size") or [0, 0]
        at = win.get("at") or [0, 0]
        if not mon or not work or work["w"] <= 0 or work["h"] <= 0:
            continue
        if size[0] <= 0 or size[1] <= 0:
            continue
        dx, dy = nearest_offscreen(at, size, work)
        saved.append({
            "address": win["address"],
            "floating": bool(win.get("floating")),
            "fullscreen": int(win.get("fullscreen") or 0),
            "x": int(at[0]),
            "y": int(at[1]),
            "dx": dx,
            "dy": dy,
        })
    if not saved:
        return
    with open(state_path, "w") as fh:
        json.dump(saved, fh)
    prep, moves = [], []
    for row in saved:
        a = selector(row["address"])
        if row["fullscreen"]:
            prep.append(f'hl.dsp.window.fullscreen({{ action = "unset", window = "{a}" }})')
        if not row["floating"]:
            prep.append(f'hl.dsp.window.float({{ action = "set", window = "{a}" }})')
        moves.append(
            f'hl.dsp.window.move({{ window = "{a}", x = {row["dx"]}, y = {row["dy"]}, relative = false }})'
        )
    batch(prep)
    batch(moves)


def hide(state_path):
    try:
        with open(state_path) as fh:
            saved = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return
    alive = {c.get("address") for c in hypr_json("clients")}
    moves, unfloat, full = [], [], []
    for row in saved:
        if row.get("address") not in alive:
            continue
        a = selector(row["address"])
        moves.append(
            f'hl.dsp.window.move({{ window = "{a}", x = {int(row["x"])}, y = {int(row["y"])}, relative = false }})'
        )
        if not row.get("floating"):
            unfloat.append(f'hl.dsp.window.float({{ action = "unset", window = "{a}" }})')
        fs = int(row.get("fullscreen") or 0)
        if fs == 2:
            full.append(f'hl.dsp.window.fullscreen({{ action = "set", mode = "fullscreen", window = "{a}" }})')
        elif fs == 1:
            full.append(f'hl.dsp.window.fullscreen({{ action = "set", mode = "maximized", window = "{a}" }})')
    batch(moves)
    if unfloat or full:
        time.sleep(0.32)
        batch(unfloat)
        batch(full)
    try:
        os.remove(state_path)
    except FileNotFoundError:
        pass


def main():
    if len(sys.argv) != 3 or sys.argv[2] not in {"show", "hide"}:
        print("usage: desktop-aside.py STATE show|hide", file=sys.stderr)
        sys.exit(2)
    state_path, action = sys.argv[1], sys.argv[2]
    if action == "show":
        show(state_path)
    else:
        hide(state_path)


if __name__ == "__main__":
    main()
