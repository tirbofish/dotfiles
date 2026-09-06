#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_RUNTIME_DIR:-/tmp}/tirbofish-desktop-mode"
state="$state_dir/windows.json"
overview_socket="${XDG_RUNTIME_DIR:-/tmp}/hyprfloat/overview.sock"
mkdir -p "$state_dir"
exec 9>"$state_dir/lock"
flock 9

mission_plugin_loaded() {
    hyprctl plugin list 2>/dev/null | grep -q hymission
}

close_mission() {
    if mission_plugin_loaded; then
        hyprctl -q dispatch 'hl.plugin.hymission.close()'
    elif [[ -S "$overview_socket" ]]; then
        hyprfloat overview >/dev/null 2>&1
    fi
}

restore_desktop() {
    [[ -f "$state" ]] || return 0
    while IFS=$'\t' read -r address workspace; do
        hyprctl -q dispatch "hl.dsp.window.move({ workspace = \"name:$workspace\", silent = true, window = \"address:$address\" })"
    done < <(jq -r '.[] | [.address, .workspace] | @tsv' "$state")
    rm -f "$state"
}

show_desktop() {
    close_mission
    if [[ -f "$state" ]]; then
        restore_desktop
        return
    fi

    active="$(hyprctl monitors -j | jq '[.[].activeWorkspace.id]')"
    hyprctl clients -j | jq --argjson active "$active" '
        [.[] | select(.mapped and (.pinned | not)
          and (.workspace.id as $id | $active | index($id)))
          | {address, workspace: .workspace.name}]' > "$state"
    while IFS=$'\t' read -r address; do
        hyprctl -q dispatch "hl.dsp.window.move({ workspace = \"special:show-desktop\", silent = true, window = \"address:$address\" })"
    done < <(jq -r '.[] | [.address] | @tsv' "$state")
}

open_mission() {
    restore_desktop
    if mission_plugin_loaded; then
        hyprctl -q dispatch 'hl.plugin.hymission.open("onlycurrentworkspace")'
    elif [[ ! -S "$overview_socket" ]]; then
        hyprfloat overview 9>&- >/dev/null 2>&1 &
    fi
}

toggle_mission() {
    restore_desktop
    if mission_plugin_loaded; then
        hyprctl -q dispatch 'hl.plugin.hymission.toggle("onlycurrentworkspace")'
    else
        hyprfloat overview 9>&- >/dev/null 2>&1 &
    fi
}

case "${1:-}" in
    mission) open_mission ;;
    close-mission) close_mission ;;
    mission-toggle) toggle_mission ;;
    desktop) show_desktop ;;
    *) echo "usage: ${0##*/} mission|close-mission|mission-toggle|desktop" >&2; exit 2 ;;
esac
