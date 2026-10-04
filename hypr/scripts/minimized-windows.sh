#!/usr/bin/env bash
set -euo pipefail

action="${1:-menu}"
address="${2:-}"

normalize_address() {
    [[ "$1" =~ ^(0x)?[[:xdigit:]]+$ ]] || exit 1
    [[ "$1" == 0x* ]] && printf '%s' "$1" || printf '0x%s' "$1"
}

hide() {
    local target geo
    target="$(normalize_address "${1:-$(hyprctl -j activewindow | jq -r .address)}")"
    hyprctl -q dispatch "hl.dsp.window.fullscreen({ action = \"unset\", window = \"address:$target\" })"
    # x y w h monitor-name, for the dock's genie animation.
    geo="$(jq -r --arg a "$target" --argjson mons "$(hyprctl -j monitors)" \
        '.[] | select(.address == $a) | . as $c
         | "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1]) \($mons[] | select(.id == $c.monitor) | .name)"' \
        <<<"$(hyprctl -j clients)")"
    # shellcheck disable=SC2086
    [[ -n "$geo" ]] && qs ipc call dock minimize "$target" $geo >/dev/null 2>&1 && return
    hyprctl -q dispatch "hl.dsp.window.move({ workspace = \"special:minimized\", follow = false, window = \"address:$target\" })"
}

show() {
    local target workspace
    target="$(normalize_address "$1")"
    qs ipc call dock restore "$target" >/dev/null 2>&1 && return
    workspace="$(hyprctl -j activeworkspace | jq -r .id)"
    hyprctl -q dispatch "hl.dsp.window.move({ workspace = $workspace, follow = false, window = \"address:$target\" })"
    hyprctl -q dispatch "hl.dsp.focus({ window = \"address:$target\" })"
    hyprctl -q dispatch "hl.dsp.window.alter_zorder({ mode = \"top\", window = \"address:$target\" })"
}

case "$action" in
    hide) hide "$address" ;;
    show) show "$address" ;;
    menu)
        clients="$(hyprctl -j clients)"
        count="$(jq '[.[] | select(.workspace.name == "special:minimized")] | length' <<<"$clients")"
        if (( count == 0 )); then
            notify-send "Minimized windows" "No minimized windows"
            exit 0
        fi
        mode="$(cat "$HOME/.cache/quickshell/theme_mode" 2>/dev/null || echo dark)"
        theme="$HOME/.config/rofi/style-dark.rasi"
        [[ "$mode" == "light" ]] && theme="$HOME/.config/rofi/style-light.rasi"
        index="$(jq -r '[.[] | select(.workspace.name == "special:minimized")] | .[] | "\(.title)  (\(.class))"' <<<"$clients" |
            rofi -dmenu -i -format i -p "Restore window" -theme "$theme" \
                -theme-str 'window { location: center; anchor: center; width: 520px; x-offset: 0; y-offset: 0; }' \
                -theme-str 'mainbox { children: [ "inputbar", "listbox" ]; }' \
                -theme-str 'mode-switcher { enabled: false; }' \
                -l "$count")" || exit 0
        [[ "$index" =~ ^[0-9]+$ ]] || exit 0
        address="$(jq -r --argjson i "$index" '[.[] | select(.workspace.name == "special:minimized")][$i].address' <<<"$clients")"
        show "$address"
        ;;
    *) exit 2 ;;
esac
