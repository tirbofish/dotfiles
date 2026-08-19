#!/usr/bin/env sh

scriptdir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sink=$("$scriptdir/volume-sink.sh")

case $1 in
  i) pamixer --sink "$sink" -i 5 ;;
  d) pamixer --sink "$sink" -d 5 ;;
  m) pamixer --sink "$sink" -t ;;
  s) pamixer --sink "$sink" --set-volume "$2" ;;
  *) echo "Usage: $0 {i|d|m|s <percent>}" ; exit 1 ;;
esac

vol=$(pamixer --sink "$sink" --get-volume)
is_muted=$(pamixer --sink "$sink" --get-mute)

if [ "$is_muted" = "true" ]; then
echo "${vol}:${is_muted}" > "$HOME/.cache/quickshell/volume"
printf '%s\n%s\n%s' "$status" "$title" "$artist" > "$HOME/.cache/quickshell/media"
else
echo "${vol}:${is_muted}" > "$HOME/.cache/quickshell/volume"
fi
