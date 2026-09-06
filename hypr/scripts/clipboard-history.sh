#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:/usr/bin:/usr/local/bin:$PATH"

mode="$(cat "$HOME/.cache/quickshell/theme_mode" 2>/dev/null || echo dark)"
theme="$HOME/.config/rofi/style-dark.rasi"
[[ "$mode" == "light" ]] && theme="$HOME/.config/rofi/style-light.rasi"

rofi_bin="$(command -v rofi || true)"
if [[ -z "$rofi_bin" ]]; then
    notify-send "Clipboard" "rofi not found"
    exit 1
fi

list="$(cliphist list)" || true
if [[ -z "${list}" ]]; then
    notify-send "Clipboard" "History is empty"
    exit 0
fi

selected="$(printf '%s\n' "$list" | "$rofi_bin" -dmenu -i -p "Clipboard" -theme "$theme" \
    -theme-str 'window { location: center; anchor: center; width: 560px; x-offset: 0; y-offset: 0; }' \
    -theme-str 'mainbox { children: [ "inputbar", "listbox" ]; }' \
    -theme-str 'mode-switcher { enabled: false; }')" || exit 0
[[ -z "$selected" ]] && exit 0

cliphist decode <<<"$selected" | wl-copy
