#!/usr/bin/env bash
# Apply persisted pointer settings to the running compositor, including
# per-device touchpad/mouse overrides that cannot be set until devices exist.
set -uo pipefail

json="${HOME}/.config/quickshell/lib/inputsettings.json"
[[ -f "$json" ]] || exit 0
command -v hyprctl >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

lua_str() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '"%s"' "$s"
}

bool() { [[ "$1" == "true" ]] && echo true || echo false; }

# jq's // treats false as missing, so boolean defaults cannot use it.
jq_num() { jq -r --arg k "$1" --argjson d "$2" 'if has($k) then .[$k] else $d end' "$json"; }
jq_bool() { jq -r --arg k "$1" --argjson d "$2" 'if has($k) then .[$k] else $d end' "$json"; }

mouseSpeed="$(jq_num mouseSpeed 0.35)"
mouseAcceleration="$(jq_bool mouseAcceleration true)"
mouseNaturalScroll="$(jq_bool mouseNaturalScroll false)"
mouseLeftHanded="$(jq_bool mouseLeftHanded false)"
touchpadSpeed="$(jq_num touchpadSpeed 0.35)"
touchpadNaturalScroll="$(jq_bool touchpadNaturalScroll true)"
touchpadTapToClick="$(jq_bool touchpadTapToClick true)"
touchpadDisableWhileTyping="$(jq_bool touchpadDisableWhileTyping true)"

if [[ "$mouseAcceleration" == "true" ]]; then
  accel_profile="adaptive"
else
  accel_profile="flat"
fi

hyprctl eval "hl.config({ input = {
  sensitivity = ${mouseSpeed},
  accel_profile = $(lua_str "$accel_profile"),
  natural_scroll = $(bool "$mouseNaturalScroll"),
  left_handed = $(bool "$mouseLeftHanded"),
  touchpad = {
    natural_scroll = $(bool "$touchpadNaturalScroll"),
    tap_to_click = $(bool "$touchpadTapToClick"),
    disable_while_typing = $(bool "$touchpadDisableWhileTyping")
  }
} })" >/dev/null

devices="$(hyprctl devices -j 2>/dev/null || echo '{}')"
while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  if [[ "${name,,}" =~ touchpad|trackpad|clickpad ]]; then
    hyprctl eval "hl.device({
      name = $(lua_str "$name"),
      sensitivity = ${touchpadSpeed},
      natural_scroll = $(bool "$touchpadNaturalScroll"),
      left_handed = false
    })" >/dev/null || true
  else
    hyprctl eval "hl.device({
      name = $(lua_str "$name"),
      accel_profile = $(lua_str "$accel_profile")
    })" >/dev/null || true
  fi
done < <(jq -r '.mice[]?.name // empty' <<<"$devices")

# hyprctl eval is wiped by reload; re-apply lid-gated touchscreen after devices exist.
"${HOME}/.config/hypr/scripts/lid-touchscreen.sh" >/dev/null || true
