#!/usr/bin/env python3
"""Voyager 1 & 2 distance from Earth, from NASA JPL Horizons.

Prints JSON: daily samples around today (time ms, AU from Earth, km/s away)
for each probe, plus when Voyager 1 passes one light-day from Earth.
Horizons is asked at most once a day; the cache keeps the widget alive offline.
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

AU_KM = 149597870.7
C_KM_S = 299792.458
LIGHT_DAY_AU = 86400 * C_KM_S / AU_KM
CACHE = os.path.expanduser("~/.cache/quickshell/voyager.json")
PROBES = {"v1": "-31", "v2": "-32"}
MONTHS = {m: i + 1 for i, m in enumerate("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split())}


def fetch(target, start, stop):
    q = urllib.parse.urlencode({
        "format": "json", "COMMAND": f"'{target}'", "EPHEM_TYPE": "'OBSERVER'",
        "CENTER": "'500@399'", "QUANTITIES": "'20'", "STEP_SIZE": "'1d'",
        "START_TIME": f"'{start:%Y-%m-%d}'", "STOP_TIME": f"'{stop:%Y-%m-%d}'",
    })
    with urllib.request.urlopen("https://ssd.jpl.nasa.gov/api/horizons.api?" + q, timeout=40) as r:
        return parse(json.load(r)["result"])


def parse(result):
    """Horizons table rows -> [[epoch ms, delta AU, deldot km/s], ...]."""
    body = result[result.index("$$SOE") + 5:result.index("$$EOE")]
    rows = []
    for line in body.strip().splitlines():
        p = line.split()
        y, mon, d = p[0].split("-")
        hh, mm = p[1].split(":")
        t = datetime(int(y), MONTHS[mon], int(d), int(hh), int(mm), tzinfo=timezone.utc)
        rows.append([int(t.timestamp() * 1000), float(p[-2]), float(p[-1])])
    return rows


def crossing(rows, level=LIGHT_DAY_AU):
    """First time (ms) the distance rises through `level`, linearly interpolated."""
    for (t0, a, _), (t1, b, _) in zip(rows, rows[1:]):
        if a < level <= b:
            return int(t0 + (t1 - t0) * (level - a) / (b - a))
    return None


def near(rows, now_ms, before=2, after=3):
    i = next((k for k, r in enumerate(rows) if r[0] > now_ms), len(rows))
    return rows[max(0, i - before):i + after]


def load():
    now = datetime.now(timezone.utc)
    try:
        with open(CACHE) as f:
            cache = json.load(f)
        if cache.get("day") == f"{now:%Y-%m-%d}":
            return cache
    except (OSError, ValueError):
        cache = None
    try:
        start = now - timedelta(days=2)
        fresh = {"day": f"{now:%Y-%m-%d}", "fetched": int(time.time() * 1000)}
        fresh["v1"] = fetch(PROBES["v1"], start, start + timedelta(days=500))
        fresh["v2"] = fetch(PROBES["v2"], start, start + timedelta(days=5))
        # Once it's behind us the new window can't see it, so remember it.
        fresh["crossing"] = crossing(fresh["v1"]) or (cache or {}).get("crossing")
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        with open(CACHE, "w") as f:
            json.dump(fresh, f)
        return fresh
    except Exception:  # offline: the widget extrapolates from old samples
        return cache


def main():
    data = load()
    if not data:
        print(json.dumps({"error": "No data yet (offline?)"}))
        return
    now_ms = int(time.time() * 1000)
    print(json.dumps({
        "fetched": data["fetched"],
        "lightDayAu": LIGHT_DAY_AU,
        "crossing": data.get("crossing"),
        "v1": near(data["v1"], now_ms),
        "v2": near(data["v2"], now_ms),
    }))


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        sample = "x\n$$SOE\n 2026-Nov-19 00:00     173.100000000  40.0\n 2026-Nov-20 00:00     173.200000000  39.0\n$$EOE\n"
        rows = parse(sample)
        assert rows[0][0] == int(datetime(2026, 11, 19, tzinfo=timezone.utc).timestamp() * 1000)
        t = crossing(rows)
        assert rows[0][0] < t < rows[1][0] and abs((t - rows[0][0]) / 86400000 - 0.4463) < 0.001
        assert crossing([[0, 174, 0], [1, 175, 0]]) is None
        assert len(near([[i, 0, 0] for i in range(10)], 5)) == 5
        print("voyager: ok")
    else:
        main()
