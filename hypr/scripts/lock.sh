#!/usr/bin/env bash
# Lock with hyprlock, then run Biopass after lock_buffer seconds for
# var_timeout seconds. Further password keystrokes start another window.
set -euo pipefail

if pidof hyprlock >/dev/null 2>&1; then
  exit 0
fi

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprlock-biopass.conf"
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
ARMED="$RUNTIME/hyprlock-biopass.armed"
TRIGGER="$RUNTIME/hyprlock-biopass.trigger"
DONE="$RUNTIME/hyprlock-biopass.done"
STATUS="$RUNTIME/hyprlock-biopass.status"
LOCKDIR="$RUNTIME/hyprlock-biopass.lock"
HELPER="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/hyprlock-biopass.sh"

read_conf() {
  local key="$1" default="$2" value=""
  if [[ -f "$CONF" ]]; then
    value="$(awk -F= -v k="$key" '
      $0 ~ "^[[:space:]]*" k "[[:space:]]*=" {
        sub(/^[^=]*=/, "")
        gsub(/^[[:space:]]+|[[:space:]]+$/, "")
        gsub(/#.*/, "")
        gsub(/[[:space:]]+$/, "")
        print
        exit
      }
    ' "$CONF")"
  fi
  printf '%s' "${value:-$default}"
}

buffer_s="$(read_conf lock_buffer 1)"
[[ "$buffer_s" =~ ^[0-9]+([.][0-9]+)?$ ]] || buffer_s=1

waiter_pid=""
stop_biopass() { :; }
cleanup() {
  stop_biopass
  if [[ -n "$waiter_pid" ]]; then
    wait "$waiter_pid" 2>/dev/null || true
    waiter_pid=""
  fi
  rm -f "$ARMED" "$TRIGGER" "$DONE" "$STATUS"
  rmdir "$LOCKDIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

rm -f "$TRIGGER" "$DONE" "$STATUS"
: >"$STATUS"
: >"$ARMED"

hyprlock "$@" &
hyprlock_pid=$!

stop_biopass() {
  rm -f "$ARMED" "$TRIGGER"
  if [[ -n "$waiter_pid" ]]; then
    kill "$waiter_pid" 2>/dev/null || true
    pkill -P "$waiter_pid" 2>/dev/null || true
  fi
  pkill -f '/hyprlock-biopass-auth( |$)' 2>/dev/null || true
  pkill -f '/hyprlock-biopass\.sh window' 2>/dev/null || true
}

wait_until_hyprlock() {
  local i
  for i in $(seq 1 50); do
    pidof hyprlock >/dev/null 2>&1 && return 0
    kill -0 "$hyprlock_pid" 2>/dev/null || return 1
    sleep 0.05
  done
  return 1
}

biopass_loop() {
  wait_until_hyprlock || return 0
  sleep "$buffer_s"
  while pidof hyprlock >/dev/null 2>&1; do
    [[ -f "$DONE" || ! -f "$ARMED" ]] && break
    "$HELPER" window
    [[ -f "$DONE" || ! -f "$ARMED" ]] && break
    pidof hyprlock >/dev/null 2>&1 || break
    rm -f "$TRIGGER"
    while pidof hyprlock >/dev/null 2>&1 && [[ ! -f "$TRIGGER" && ! -f "$DONE" && -f "$ARMED" ]]; do
      sleep 0.05
    done
  done
}

biopass_loop &
waiter_pid=$!

wait "$hyprlock_pid"
stop_biopass
if [[ -n "$waiter_pid" ]]; then
  wait "$waiter_pid" 2>/dev/null || true
  waiter_pid=""
fi
