#!/usr/bin/env bash
# Enable/disable the built-in Surface touchscreen and stylus.
# Usage: lid-touchscreen.sh [on|off]
# No args: follow /proc/acpi lid state (closed = off).
set -uo pipefail

command -v hyprctl >/dev/null 2>&1 || exit 0

state="${1:-}"
if [[ -z "$state" ]]; then
  if grep -q closed /proc/acpi/button/lid/*/state 2>/dev/null; then
    state=off
  else
    state=on
  fi
fi

case "$state" in
  off|closed|disable|0) enabled=false ;;
  on|open|enable|1)     enabled=true  ;;
  *) echo "usage: $0 [on|off]" >&2; exit 1 ;;
esac

lua_str() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '"%s"' "$s"
}

# Global switch is enough for finger-touch; per-device also covers stylus.
hyprctl eval "hl.config({ input = { touchdevice = { enabled = ${enabled} } } })" >/dev/null || true

devices="$(hyprctl devices -j 2>/dev/null || echo '{}')"
if command -v jq >/dev/null 2>&1; then
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    hyprctl eval "hl.device({ name = $(lua_str "$name"), enabled = ${enabled} })" >/dev/null || true
  done < <(jq -r '((.touch // []) + (.tablets // []))[]?.name // empty' <<<"$devices")
else
  for name in \
    iptsd-virtual-touchscreen-045e:0c31 \
    intel-touch-host-controller \
    iptsd-virtual-stylus-045e:0c31 \
    intel-touch-host-controller-stylus
  do
    hyprctl eval "hl.device({ name = $(lua_str "$name"), enabled = ${enabled} })" >/dev/null || true
  done
fi
