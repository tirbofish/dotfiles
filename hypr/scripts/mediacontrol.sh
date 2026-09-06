#!/usr/bin/env sh

case "${1:-toggle}" in
  next) playerctl next ;;
  prev|previous) playerctl previous ;;
  stop) playerctl stop ;;
  *) playerctl play-pause ;;
esac

sleep 0.2

status=$(playerctl status 2>/dev/null)
title=$(playerctl metadata title 2>/dev/null)
artist=$(playerctl metadata artist 2>/dev/null)
artUrl=$(playerctl metadata mpris:artUrl 2>/dev/null)

icon="audio-x-generic"
tmp_cover="/tmp/cover_art.jpg"

if [ -n "$artUrl" ]; then
    if echo "$artUrl" | grep -q "^file://"; then
        icon=${artUrl#file://}
    elif echo "$artUrl" | grep -q "^http"; then
        curl -s --max-time 1 "$artUrl" -o "$tmp_cover"
        icon="$tmp_cover"
    fi
fi

case "$1" in
  next) heading="Next" ;;
  prev|previous) heading="Previous" ;;
  stop) heading="Stopped" ;;
  *)
    if [ "$status" = "Paused" ]; then
      heading="Paused"
    else
      heading="Playing"
    fi
    ;;
esac

if [ -n "$status" ] || [ -n "$title" ]; then
    notify-send -c media \
        -i "$icon" \
        -h string:x-canonical-private-synchronous:media \
        "$heading" "${title:-}${artist:+ - $artist}"
fi