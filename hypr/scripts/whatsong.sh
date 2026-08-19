#!/usr/bin/env sh

case "${1:-}" in
  --title) playerctl metadata title 2>/dev/null ;;
  --artist) playerctl metadata artist 2>/dev/null ;;
  *) exit 1 ;;
esac
