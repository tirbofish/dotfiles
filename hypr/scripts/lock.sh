#!/usr/bin/env bash
# Lock with hyprlock, then run Biopass after lock_buffer seconds for
# var_timeout seconds. Further password keystrokes start another window.
# --no-biopass: lock only (used before suspend). If hyprlock is already
# running, just disarm Biopass and exit.
set -euo pipefail

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprlock-biopass.conf"
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
ARMED="$RUNTIME/hyprlock-biopass.armed"
TRIGGER="$RUNTIME/hyprlock-biopass.trigger"
DONE="$RUNTIME/hyprlock-biopass.done"
STATUS="$RUNTIME/hyprlock-biopass.status"
LOCKDIR="$RUNTIME/hyprlock-biopass.lock"
SKIP="$RUNTIME/hyprlock-skip-biopass"
HELPER="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/hyprlock-biopass.sh"

no_biopass=0
lid_open=0
hyprlock_args=()
for arg in "$@"; do
  case "$arg" in
    --no-biopass) no_biopass=1 ;;
    --lid-open) lid_open=1 ;;
    *) hyprlock_args+=("$arg") ;;
  esac
done
[[ -f "$SKIP" ]] && no_biopass=1
rm -f "$SKIP"

lid_closed() {
  grep -q closed /proc/acpi/button/lid/*/state 2>/dev/null
}

stop_biopass_procs() {
  rm -f "$ARMED" "$TRIGGER"
  pkill -f '/hyprlock-biopass-auth( |$)' 2>/dev/null || true
  pkill -f '/hyprlock-biopass\.sh window' 2>/dev/null || true
  rmdir "$LOCKDIR" 2>/dev/null || true
}

if (( lid_open )); then
  pidof hyprlock >/dev/null 2>&1 || exit 0
  lid_closed && exit 0
  [[ -f "$DONE" ]] && exit 0
  : >"$ARMED"
  rm -f "$TRIGGER"
  "$HELPER" window >/dev/null 2>&1 &
  exit 0
fi

if pidof hyprlock >/dev/null 2>&1; then
  if (( no_biopass )); then
    stop_biopass_procs
  fi
  exit 0
fi

if (( no_biopass )) || lid_closed; then
  no_biopass=1
fi

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

hyprlock "${hyprlock_args[@]}" &
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

wait_for_trigger() {
  while pidof hyprlock >/dev/null 2>&1 && [[ ! -f "$TRIGGER" && ! -f "$DONE" && -f "$ARMED" ]]; do
    if command -v inotifywait >/dev/null 2>&1; then
      inotifywait -q -t 5 -e create,close_write,moved_to "$RUNTIME" >/dev/null 2>&1 || true
    else
      sleep 1
    fi
  done
}

biopass_loop() {
  wait_until_hyprlock || return 0
  sleep "$buffer_s"
  lid_closed && return 0
  while pidof hyprlock >/dev/null 2>&1; do
    [[ -f "$DONE" || ! -f "$ARMED" ]] && break
    lid_closed && break
    "$HELPER" window
    [[ -f "$DONE" || ! -f "$ARMED" ]] && break
    pidof hyprlock >/dev/null 2>&1 || break
    rm -f "$TRIGGER"
    wait_for_trigger
  done
}

if (( ! no_biopass )); then
  : >"$ARMED"
  biopass_loop &
  waiter_pid=$!
fi

wait "$hyprlock_pid"
stop_biopass
if [[ -n "$waiter_pid" ]]; then
  wait "$waiter_pid" 2>/dev/null || true
  waiter_pid=""
fi
