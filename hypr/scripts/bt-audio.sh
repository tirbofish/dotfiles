#!/usr/bin/env bash
# Pair/connect a Bluetooth headset and route PipeWire to its A2DP sink.
set -euo pipefail

ADDR="${1:-2C:BE:EE:3C:42:F2}"
CARD="bluez_card.${ADDR//:/_}"

bluetoothctl power on >/dev/null
bluetoothctl trust "$ADDR" >/dev/null || true

if ! bluetoothctl info "$ADDR" 2>/dev/null | grep -q "Paired: yes"; then
  bluetoothctl pair "$ADDR"
fi

bluetoothctl connect "$ADDR"

for _ in $(seq 1 20); do
  if pactl list cards short 2>/dev/null | grep -q "$CARD"; then
    break
  fi
  sleep 0.4
done

if ! pactl list cards short 2>/dev/null | grep -q "$CARD"; then
  echo "Bluetooth card $CARD never appeared" >&2
  exit 1
fi

pactl set-card-profile "$CARD" a2dp-sink 2>/dev/null \
  || pactl set-card-profile "$CARD" a2dp-sink-sbc_xq 2>/dev/null \
  || true

SINK="$(pactl list sinks short | awk -v pref="bluez_output.${ADDR//:/_}" '$2 ~ pref { print $2; exit }')"
if [[ -z "$SINK" ]]; then
  echo "No A2DP sink for $ADDR" >&2
  exit 1
fi

pactl set-default-sink "$SINK"
pactl list sink-inputs short | awk '{print $1}' | while read -r id; do
  [[ -n "$id" ]] && pactl move-sink-input "$id" "$SINK" || true
done

echo "Audio routed to $SINK"
