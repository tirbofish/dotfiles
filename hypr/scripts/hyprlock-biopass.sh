#!/usr/bin/env bash
# Biopass windows for hyprlock.
#   status — pango line for the lockscreen label
#   window — run Biopass until success, hyprlock exit, or var_timeout
set -euo pipefail

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprlock-biopass.conf"
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
ARMED="$RUNTIME/hyprlock-biopass.armed"
TRIGGER="$RUNTIME/hyprlock-biopass.trigger"
DONE="$RUNTIME/hyprlock-biopass.done"
LOCKDIR="$RUNTIME/hyprlock-biopass.lock"
STATUS="$RUNTIME/hyprlock-biopass.status"
LOG="$RUNTIME/hyprlock-biopass.log"
AUTH="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/hyprlock-biopass-auth"
auth_pid=""

log() { printf '%s %s\n' "$(date -Iseconds)" "$*" >>"$LOG"; }

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

write_status() {
  local tmp="${STATUS}.tmp"
  printf '%s' "$1" >"$tmp"
  mv -f "$tmp" "$STATUS"
}

unlock_hyprlock() {
  local pid
  for pid in $(pidof hyprlock || true); do
    log "SIGUSR1 hyprlock pid=$pid"
    kill -USR1 "$pid" 2>/dev/null || true
  done
}

cmd="${1:-window}"

if [[ "$cmd" == "status" ]]; then
  [[ -r "$STATUS" ]] && cat "$STATUS"
  exit 0
fi

[[ -f "$ARMED" && ! -f "$DONE" ]] || exit 0
pidof hyprlock >/dev/null 2>&1 || exit 0
mkdir "$LOCKDIR" 2>/dev/null || exit 0
cleanup() {
  if [[ -n "$auth_pid" ]]; then
    kill "$auth_pid" 2>/dev/null || true
    wait "$auth_pid" 2>/dev/null || true
    auth_pid=""
  fi
  rmdir "$LOCKDIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

timeout_s="$(read_conf var_timeout 5)"
[[ "$timeout_s" =~ ^[0-9]+([.][0-9]+)?$ ]] || timeout_s=5
timeout_s="${timeout_s%%.*}"
(( timeout_s > 0 )) || timeout_s=5

write_status "Looking at camera…"
log "window start var_timeout=${timeout_s}s"
rm -f "$TRIGGER"

user_name="$(id -un)"
deadline=$((SECONDS + timeout_s))
success=0

while (( SECONDS < deadline )); do
  pidof hyprlock >/dev/null 2>&1 || break
  [[ -f "$ARMED" && ! -f "$DONE" ]] || break
  remaining=$((deadline - SECONDS))
  (( remaining > 0 )) || break

  set +e
  "$AUTH" "$user_name" hyprlock-biopass >>"$LOG" 2>&1 &
  auth_pid=$!
  while kill -0 "$auth_pid" 2>/dev/null; do
    if ! pidof hyprlock >/dev/null 2>&1 || [[ ! -f "$ARMED" || -f "$DONE" ]] || (( SECONDS >= deadline )); then
      kill "$auth_pid" 2>/dev/null || true
      break
    fi
    sleep 0.1
  done
  wait "$auth_pid"
  ec=$?
  auth_pid=""
  set -e
  log "pam auth exit=$ec remaining=${remaining}s"

  if (( ec == 0 )); then
    success=1
    break
  fi
  if (( ec == 124 || ec == 137 || ec == 143 )); then
    break
  fi
  sleep 0.2
done

if (( success )); then
  : >"$DONE"
  rm -f "$ARMED" "$TRIGGER"
  write_status "Unlocking…"
  unlock_hyprlock
else
  write_status "Use password"
  log "window ended without success"
fi
