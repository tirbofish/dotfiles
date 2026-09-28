#!/usr/bin/env python3
import json
import re
from pathlib import Path

ROOT = Path(__file__).parents[1]
service = (ROOT / "lib/WidgetService.qml").read_text()
shell = (ROOT / "desktop/WidgetShell.qml").read_text()
catalog = set(re.findall(r'\{ type: "([^"]+)"', service))
loaders = set(re.findall(r'case "([^"]+)": return', shell))
packed = {w["type"] for p in json.loads((ROOT / "desktop/packs.json").read_text())["packs"] for w in p["widgets"]}

assert catalog == loaders, f"catalog/loader mismatch: {catalog ^ loaders}"
assert packed <= catalog, f"unknown packed widgets: {packed - catalog}"
