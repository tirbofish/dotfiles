#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:/usr/bin:/usr/local/bin:$PATH"

settings="$HOME/.config/quickshell/lib/usersettings.json"
clip_conf_dir="${XDG_CONFIG_HOME:-$HOME/.config}/cliphist"
clip_conf="$clip_conf_dir/config"
boot_stamp="${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/boot_id"
default_n=20
min_n=1
max_n=200

max_items() {
    local n="$default_n"
    if [[ -f "$settings" ]] && command -v jq >/dev/null; then
        n="$(jq -r '.clipboardMaxItems // empty' "$settings" 2>/dev/null || true)"
    fi
    [[ "$n" =~ ^[0-9]+$ ]] || n="$default_n"
    if (( n < min_n )); then n="$min_n"; fi
    if (( n > max_n )); then n="$max_n"; fi
    printf '%s' "$n"
}

write_config() {
    mkdir -p "$clip_conf_dir"
    printf 'max-items %s\n' "$(max_items)" > "$clip_conf"
}

trim() {
    write_config
    local n extras
    n="$(max_items)"
    extras="$(cliphist list 2>/dev/null | tail -n +"$((n + 1))" || true)"
    [[ -z "$extras" ]] && return 0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        printf '%s\n' "$line" | cliphist delete || true
    done <<< "$extras"
}

wipe_all() {
    cliphist wipe >/dev/null 2>&1 || true
}

start_watchers() {
    if ! pgrep -ax wl-paste | grep -q -- '--type text --watch cliphist'; then
        setsid -f wl-paste --type text --watch cliphist store >/dev/null 2>&1
    fi
    if ! pgrep -ax wl-paste | grep -q -- '--type image --watch cliphist'; then
        setsid -f wl-paste --type image --watch cliphist store >/dev/null 2>&1
    fi
}

boot() {
    mkdir -p "$(dirname "$boot_stamp")"
    local boot_id
    boot_id="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo unknown)"
    if [[ ! -f "$boot_stamp" ]] || [[ "$(cat "$boot_stamp" 2>/dev/null || true)" != "$boot_id" ]]; then
        wipe_all
        printf '%s\n' "$boot_id" > "$boot_stamp"
    fi
    write_config
    trim
    start_watchers
}

picker() {
    local mode theme rofi_bin list selected
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
}

cmd="${1:-picker}"
case "$cmd" in
    picker) picker ;;
    apply) trim ;;
    boot) boot ;;
    wipe) wipe_all ;;
    *)
        echo "usage: $0 [picker|apply|boot|wipe]" >&2
        exit 1
        ;;
esac
