#!/usr/bin/env sh
# Resolves the sink that volume changes should actually be applied to.
#
# Filter-chain "enhanced" sinks (e.g. the Surface speaker profile) are virtual
# PipeWire nodes used purely for routing audio through an impulse-response
# convolver; they don't apply their own volume to the signal, so their level
# always reads back as 100%. The real gain lives on the physical sink
# underneath. When the default sink is one of these virtual nodes, resolve to
# the first non-virtual sink instead so volume keys/UI move real loudness.
default_sink=$(pactl get-default-sink 2>/dev/null)

is_virtual=$(pactl -f json list sinks 2>/dev/null | jq -r --arg n "$default_sink" \
    '(.[] | select(.name==$n) | (.properties["node.virtual"] // "false")) // "false"')

if [ "$is_virtual" = "true" ]; then
    real_sink=$(pactl -f json list sinks 2>/dev/null | jq -r \
        '[.[] | select((.properties["node.virtual"] // "false") != "true")] | .[0].name // empty')
    if [ -n "$real_sink" ]; then
        echo "$real_sink"
        exit 0
    fi
fi

echo "$default_sink"
