#!/usr/bin/env bash
set -euo pipefail

target=${1:?missing output name}
switcher="$HOME/.local/bin/snappy-switcher"
if [[ ! -x "$switcher" ]]; then
    switcher="$(command -v snappy-switcher || true)"
fi

fail() {
    notify-send -u critical "Alt-Tab display" "$1"
    exit 1
}

hyprctl monitors -j | jq -e --arg output "$target" 'any(.[]; .name == $output)' >/dev/null ||
    fail "Output $target is not connected."
[ -x "$switcher" ] || fail "snappy-switcher is not installed."

current=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name' | head -n1)
if [ -n "$current" ] && [ "$current" != "$target" ]; then
    hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$target\" }))" >/dev/null ||
        fail "Could not focus $target."
fi

"$switcher" quit >/dev/null 2>&1 || true
sleep 0.2
nohup "$switcher" --daemon >/dev/null 2>&1 &
sleep 0.6

if [ -n "$current" ] && [ "$current" != "$target" ]; then
    hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$current\" }))" >/dev/null ||
        fail "Could not restore $current."
fi
