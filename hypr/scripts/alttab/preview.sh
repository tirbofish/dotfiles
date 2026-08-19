#!/usr/bin/env bash
set -euo pipefail

address="${1:?missing window address}"
preview="${XDG_RUNTIME_DIR:-/tmp}/hypr-alttab-${USER}.png"

if ! grim -T "$address" "$preview" 2>/dev/null; then
    geometry="$(hyprctl -j clients | jq -r --arg address "$address" '
        .[] | select(.address == $address) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
    ')"
    [[ -n "$geometry" ]] || exit 0
    grim -g "$geometry" "$preview" 2>/dev/null
fi

kitty +kitten icat --clear --transfer-mode=memory --scale-up \
    --place="${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}@0x0" "$preview"
