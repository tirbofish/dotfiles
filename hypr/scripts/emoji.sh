#!/usr/bin/env bash
set -euo pipefail

if command -v hypremoji >/dev/null 2>&1; then
    exec hypremoji
fi

# Fallback until hypremoji is on PATH
mode="$(cat "$HOME/.cache/quickshell/theme_mode" 2>/dev/null || echo dark)"
theme="$HOME/.config/rofi/style-dark.rasi"
[[ "$mode" == "light" ]] && theme="$HOME/.config/rofi/style-light.rasi"

cache="${XDG_CACHE_HOME:-$HOME/.cache}/hypr-emoji-list"
if [[ ! -s "$cache" ]]; then
    python3 - <<'PY' > "$cache"
import unicodedata

ranges = (
    range(0x1F300, 0x1F5FF + 1),
    range(0x1F600, 0x1F64F + 1),
    range(0x1F680, 0x1F6FF + 1),
    range(0x1F900, 0x1F9FF + 1),
    range(0x1FA70, 0x1FAFF + 1),
    range(0x2600, 0x26FF + 1),
    range(0x2700, 0x27BF + 1),
)
skip = ("FITZPATRICK", "VARIATION SELECTOR", "COMBINING")
for block in ranges:
    for i in block:
        ch = chr(i)
        try:
            name = unicodedata.name(ch)
        except ValueError:
            continue
        if any(s in name for s in skip):
            continue
        print(f"{ch}  {name.title()}")
PY
fi

selected="$(rofi -dmenu -i -p "Emoji" -theme "$theme" \
    -theme-str 'window { location: center; anchor: center; width: 480px; x-offset: 0; y-offset: 0; }' \
    -theme-str 'mainbox { children: [ "inputbar", "listbox" ]; }' \
    -theme-str 'mode-switcher { enabled: false; }' \
    < "$cache")" || exit 0
[[ -z "$selected" ]] && exit 0

emoji="${selected%% *}"
printf '%s' "$emoji" | wl-copy
