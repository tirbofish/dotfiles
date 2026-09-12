#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_RUNTIME_DIR:-/tmp}/tirbofish-desktop-mode"
state="$state_dir/windows.json"
mode_file="$state_dir/mode"
overview_socket="${XDG_RUNTIME_DIR:-/tmp}/hyprfloat/overview.sock"
mkdir -p "$state_dir"
exec 9>"$state_dir/lock"
flock 9

mission_plugin_loaded() {
    hyprctl plugin list 2>/dev/null | grep -q hymission
}

set_mode() {
    printf '%s\n' "$1" > "$mode_file"
}

current_mode() {
    if [[ -f "$state" ]]; then
        echo hidden
        return
    fi
    local recorded=""
    [[ -f "$mode_file" ]] && recorded="$(<"$mode_file")"
    case "$recorded" in
        mission) echo mission ;;
        hidden) echo hidden ;;
        *) echo normal ;;
    esac
}

close_mission() {
    if mission_plugin_loaded; then
        hyprctl -q eval 'hl.plugin.hymission.close()' || true
    elif [[ -S "$overview_socket" ]]; then
        hyprfloat overview >/dev/null 2>&1 || true
    fi
    if [[ ! -f "$state" ]]; then
        set_mode normal
    fi
}

aside() {
    python3 "${0%/*}/desktop-aside.py" "$state" "$1"
}

restore_desktop() {
    if [[ -f "$state" ]]; then
        aside hide || true
        rm -f "$state"
    fi
    set_mode normal
}

show_desktop() {
    close_mission
    if [[ -f "$state" ]]; then
        set_mode hidden
        return 0
    fi
    aside show
    if [[ -f "$state" ]]; then
        set_mode hidden
    else
        set_mode normal
    fi
}

open_mission() {
    restore_desktop
    if mission_plugin_loaded; then
        hyprctl -q eval 'hl.plugin.hymission.open("onlycurrentworkspace")' || true
        set_mode mission
    elif [[ ! -S "$overview_socket" ]]; then
        hyprfloat overview 9>&- >/dev/null 2>&1 &
        set_mode mission
    else
        set_mode normal
    fi
}

# Swipe / Super+Ctrl+Down
# normal → hidden, mission → normal, hidden → stay
gesture_down() {
    case "$(current_mode)" in
        hidden) set_mode hidden ;;
        mission) close_mission ;;
        *) show_desktop ;;
    esac
}

# Swipe / Super+Ctrl+Up
# hidden → normal, normal → mission, mission → stay
gesture_up() {
    case "$(current_mode)" in
        hidden) restore_desktop ;;
        mission) set_mode mission ;;
        *) open_mission ;;
    esac
}

toggle_desktop() {
    if [[ "$(current_mode)" == "hidden" ]]; then
        restore_desktop
    else
        show_desktop
    fi
}

toggle_mission() {
    if [[ "$(current_mode)" == "mission" ]]; then
        close_mission
    else
        open_mission
    fi
}

case "${1:-}" in
    status) current_mode ;;
    down) gesture_down ;;
    up) gesture_up ;;
    mission) open_mission ;;
    close-mission) close_mission ;;
    mission-toggle) toggle_mission ;;
    desktop) toggle_desktop ;;
    show) show_desktop ;;
    hide) restore_desktop ;;
    hide-or-mission) gesture_up ;;
    *) echo "usage: ${0##*/} status|down|up|mission|close-mission|mission-toggle|desktop|show|hide|hide-or-mission" >&2; exit 2 ;;
esac
