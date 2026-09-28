#!/usr/bin/env bash
# Cava writer for hyprlock. start/stop around the lock session;
# `bars` prints the latest unicode line for a hyprlock label.
set -euo pipefail

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/cava-lock.conf"
OUT="/dev/shm/hyprlock-cava-bars"
PIDFILE="/dev/shm/hyprlock-cava.pid"

stop() {
  if [[ -f "$PIDFILE" ]]; then
    local pid
    pid="$(cat "$PIDFILE" 2>/dev/null || true)"
    if [[ "$pid" =~ ^[0-9]+$ ]]; then
      kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
    fi
    rm -f "$PIDFILE"
  fi
}

_run() {
  printf '%s\n' "$$" >"$PIDFILE"
  trap 'kill 0' EXIT TERM INT
  local -a bars=(' ' '▁' '▂' '▃' '▄' '▅' '▆' '▇' '█')
  stdbuf -oL cava -p "$CONF" | while IFS= read -r line; do
    rendered=""
    IFS=';' read -ra vals <<<"$line"
    for n in "${vals[@]}"; do
      [[ -z "$n" ]] && continue
      if (( n < 0 )); then n=0; elif (( n > 8 )); then n=8; fi
      rendered+="${bars[n]}"
    done
    printf '%s\n' "$rendered" >"$OUT"
  done
}

start() {
  stop
  printf '\n' >"$OUT"
  command -v cava >/dev/null 2>&1 || return 0
  setsid -f "$0" _run >/dev/null 2>&1
}

bars() {
  cat "$OUT" 2>/dev/null || true
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  _run) _run ;;
  bars) bars ;;
  *) echo "usage: $0 start|stop|bars" >&2; exit 1 ;;
esac
