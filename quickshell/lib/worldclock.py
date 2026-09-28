#!/usr/bin/env python3
import json
import sys
from datetime import datetime
from zoneinfo import ZoneInfo


def resolve(value):
    value = value.strip()
    if "=" in value:
        label, zone = map(str.strip, value.split("=", 1))
        return label, zone
    return value.rsplit("/", 1)[-1].replace("_", " "), value


def clocks(spec, now=None):
    now = now or datetime.now().astimezone()
    rows = []
    for value in spec.split(",")[:6]:
        if not value.strip():
            continue
        label, zone = resolve(value)
        try:
            local = now.astimezone(ZoneInfo(zone))
            rows.append({"city": label, "time": local.strftime("%H:%M"), "day": local.strftime("%a")})
        except (KeyError, ValueError):
            rows.append({"city": label, "time": "--:--", "day": "?"})
    return rows


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        assert resolve("America/New_York") == ("New York", "America/New_York")
        assert resolve("Home=Australia/Sydney") == ("Home", "Australia/Sydney")
    else:
        print(json.dumps(clocks(sys.argv[1] if len(sys.argv) > 1 else "Australia/Sydney, UTC, America/New_York, Asia/Tokyo")))
