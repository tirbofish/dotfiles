#!/usr/bin/env bash
set -euo pipefail

cache="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
mkdir -p "$cache"
pidfile="$cache/caffeinate.pid"
conf="$HOME/.config/hypr/hypridle.conf"
settings="$HOME/.config/quickshell/lib/usersettings.json"
lock_script="$HOME/.config/hypr/scripts/lock.sh"

running() {
  local pid
  pid="$(cat "$pidfile" 2>/dev/null || true)"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

on() {
  if running; then
    echo on
    return
  fi
  systemd-inhibit --what=idle:sleep --who=Caffeinate --why="Stay awake" --mode=block \
    sleep infinity >/dev/null 2>&1 &
  echo $! > "$pidfile"
  hyprctl dispatch 'hl.dsp.dpms({action = "on"})' >/dev/null 2>&1 || true
  echo on
}

off() {
  local pid
  pid="$(cat "$pidfile" 2>/dev/null || true)"
  if [[ -n "$pid" ]]; then
    kill "$pid" >/dev/null 2>&1 || true
  fi
  rm -f "$pidfile"
  echo off
}

status() {
  if running; then echo on; else echo off; fi
}

toggle() {
  if running; then off; else on; fi
}

minutes_json() {
  local key="$1" default="$2"
  if [[ -f "$settings" ]]; then
    jq -r --arg k "$key" --argjson d "$default" '.[$k] // $d' "$settings" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

apply() {
  local lock_m screen_m sleep_m
  lock_m="$(minutes_json idleLockMin 3)"
  screen_m="$(minutes_json idleScreenOffMin 6)"
  sleep_m="$(minutes_json idleSleepMin 20)"
  lock_m="${lock_m%.*}"
  screen_m="${screen_m%.*}"
  sleep_m="${sleep_m%.*}"
  [[ "$lock_m" =~ ^[0-9]+$ ]] || lock_m=3
  [[ "$screen_m" =~ ^[0-9]+$ ]] || screen_m=6
  [[ "$sleep_m" =~ ^[0-9]+$ ]] || sleep_m=20

  local lock_s=$((lock_m * 60))
  local screen_s=$((screen_m * 60))
  local sleep_s=$((sleep_m * 60))
  local dim_s=0
  if (( lock_m > 0 )); then
    dim_s=$((lock_s - 60))
    (( dim_s < 30 )) && dim_s=30
    (( dim_s >= lock_s )) && dim_s=$((lock_s / 2))
    (( dim_s < 15 )) && dim_s=15
  fi

  {
    cat <<EOF
general {
    lock_cmd = $lock_script
    before_sleep_cmd = $HOME/.config/hypr/scripts/pre-sleep.sh
    after_sleep_cmd = $HOME/.config/hypr/scripts/post-sleep.sh
    ignore_dbus_inhibit = false
    ignore_systemd_inhibit = false
}

EOF
    if (( lock_m > 0 )); then
      cat <<EOF
listener {
    timeout = $dim_s
    on-timeout = brightnessctl -s set 10%
    on-resume = brightnessctl -r
}

listener {
    timeout = $dim_s
    on-timeout = brightnessctl -sd *::kbd_backlight set 0
    on-resume = brightnessctl -rd *::kbd_backlight
}

listener {
    timeout = $lock_s
    on-timeout = loginctl lock-session
}

EOF
    fi
    if (( screen_m > 0 )); then
      cat <<EOF
listener {
    timeout = $screen_s
    on-timeout = hyprctl dispatch 'hl.dsp.dpms({action = "off"})'
    on-resume = hyprctl dispatch 'hl.dsp.dpms({action = "on"})'
}

EOF
    fi
    if (( sleep_m > 0 )); then
      cat <<EOF
listener {
    timeout = $sleep_s
    on-timeout = systemctl suspend
}
EOF
    fi
  } > "$conf.tmp"
  mv "$conf.tmp" "$conf"

  pkill -x hypridle >/dev/null 2>&1 || true
  hypridle >/dev/null 2>&1 &
  echo "lock=${lock_m}m screen=${screen_m}m sleep=${sleep_m}m"
}

case "${1:-status}" in
  on|off|status|toggle|apply) "$1" ;;
  *) echo "usage: idle.sh on|off|toggle|status|apply" >&2; exit 1 ;;
esac
