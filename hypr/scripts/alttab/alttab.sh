#!/usr/bin/env bash
set -euo pipefail

dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/alttab"
colors="$HOME/.cache/wal/colors.json"

background="$(jq -r '.special.background' "$colors")"
foreground="$(jq -r '.special.foreground' "$colors")"
accent="$(jq -r '.colors.color4' "$colors")"
muted="$(jq -r '.colors.color8' "$colors")"

address="$(
    hyprctl -j clients |
        jq -r 'sort_by(.focusHistoryID) | .[] | select(.workspace.id >= 0) | [.address, .title, .class] | @tsv' |
        fzf --ansi --cycle --sync --wrap --layout=reverse \
            --delimiter=$'\t' --with-nth=2,3 \
            --bind='tab:down,shift-tab:up,start:down,double-click:ignore' \
            --preview="$dir/preview.sh {1}" --preview-window='down,75%,border-top' \
            --prompt='Windows  ' --pointer='●' \
            --color="bg:$background,bg+:$muted,fg:$foreground,fg+:$foreground,hl:$accent,hl+:$accent,prompt:$accent,pointer:$accent,border:$muted,gutter:$background" |
        cut -f1
)" || true

if [[ -n "$address" ]]; then
    hyprctl -q dispatch focuswindow "address:$address"
fi

hyprctl -q dispatch 'hl.dsp.submap("reset")'
hyprctl -q eval 'hl.config({ animations = { enabled = true } })'
