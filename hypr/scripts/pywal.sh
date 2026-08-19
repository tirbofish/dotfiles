#!/usr/bin/env bash
set -euo pipefail

image="${1:-$(jq -r '.wallpaper' "$HOME/.cache/wal/colors.json")}" 
image="$(readlink -f -- "$image")"
mode="${2:-dark}"
args=(-n -q -i "$image")
[[ "$mode" == "light" ]] && args+=(-l)

wal "${args[@]}"

colors="$HOME/.cache/wal/colors.json"
background="$(jq -r '.special.background' "$colors")"
foreground="$(jq -r '.special.foreground' "$colors")"
accent="$(jq -r '.colors.color4' "$colors")"
secondary="$(jq -r '.colors.color6' "$colors")"
danger="$(jq -r '.colors.color1' "$colors")"
muted="$(jq -r '.colors.color8' "$colors")"
wallpaper="$(jq -r '.wallpaper' "$colors")"

settings="$HOME/.config/quickshell/lib/usersettings.json"
if [[ -f "$settings" ]]; then
  jq --arg bg "$background" --arg fg "$foreground" --arg accent "$accent" \
     --arg secondary "$secondary" --arg danger "$danger" '
    .useCustomColors = true |
    .customBg = $bg |
    .customForeground = $fg |
    .customAccent = $accent |
    .customSecondary = $secondary |
    .customDanger = $danger |
    .taskbarAccent = $accent |
    .powerMenuLifeDark = $accent |
    .powerMenuLifeLight = $accent |
    .powerMenuCassiniDark = $accent |
    .powerMenuCassiniLight = $accent
  ' "$settings" > "$settings.tmp"
  mv "$settings.tmp" "$settings"
fi

cat > "$HOME/.cache/wal/tirbofish-hyprland.lua.tmp" <<EOF
return {
  active_border = { colors = { "rgba(${accent#\#}ee)", "rgba(${secondary#\#}ee)" }, angle = 45 },
  inactive_border = "rgba(${background#\#}aa)",
  accent = "rgb(${accent#\#})",
  secondary = "rgb(${secondary#\#})",
  background = "rgb(${background#\#})",
  foreground = "rgb(${foreground#\#})"
}
EOF
mv "$HOME/.cache/wal/tirbofish-hyprland.lua.tmp" "$HOME/.cache/wal/tirbofish-hyprland.lua"

hyprctl eval "hl.config({ general = {
  [\"col.active_border\"] = {
    colors = { \"rgba(${accent#\#}ee)\", \"rgba(${secondary#\#}ee)\" }, angle = 45
  },
  [\"col.inactive_border\"] = \"rgba(${background#\#}aa)\"
} })" >/dev/null 2>&1 || true
hyprctl reload config-only >/dev/null 2>&1 || true

mkdir -p "$HOME/.local/state/theme"
ln -sf "$HOME/.cache/wal/colors-kitty.conf" \
  "$HOME/.local/state/theme/kitty_theme.conf"
pkill -USR1 -x kitty 2>/dev/null || true

obsidian_registry="$HOME/.config/obsidian/obsidian.json"
if [[ -f "$obsidian_registry" ]]; then
  obsidian_vault="$(jq -r '([.vaults[] | select(.open == true) | .path] + [.vaults[].path])[0] // empty' "$obsidian_registry" 2>/dev/null || true)"
  obsidian_snippet="$obsidian_vault/.obsidian/snippets/surface-pywal.css"
  if [[ -f "$obsidian_snippet" ]]; then
    sed -i \
      -e "s|^  --surface-bg:.*|  --surface-bg: $background;|" \
      -e "s|^  --surface-fg:.*|  --surface-fg: $foreground;|" \
      -e "s|^  --surface-accent:.*|  --surface-accent: $accent;|" \
      -e "s|^  --surface-secondary:.*|  --surface-secondary: $secondary;|" \
      -e "s|^  --surface-danger:.*|  --surface-danger: $danger;|" \
      -e "s|^  --surface-muted:.*|  --surface-muted: $muted;|" \
      "$obsidian_snippet"
  fi
fi

snappy_config="$HOME/.config/snappy-switcher/config.ini"
if [[ -f "$snappy_config" ]]; then
  sed -i \
    -e "s|^background =.*|background = ${background}b8|" \
    -e "s|^card_bg =.*|card_bg = ${background}cc|" \
    -e "s|^card_selected =.*|card_selected = ${accent}66|" \
    -e "s|^border_color =.*|border_color = ${accent}ff|" \
    -e "s|^text_color =.*|text_color = ${foreground}ff|" \
    -e "s|^subtext_color =.*|subtext_color = ${muted}ff|" \
    -e "s|^bundle_bg =.*|bundle_bg = ${background}a6|" \
    -e "s|^badge_bg =.*|badge_bg = ${accent}e6|" \
    -e "s|^badge_text_color =.*|badge_text_color = ${background}ff|" \
    -e "s|^badge_bg_selected =.*|badge_bg_selected = ${secondary}ff|" \
    -e "s|^badge_text_color_selected =.*|badge_text_color_selected = ${background}ff|" \
    "$snappy_config"
  snappy_switcher="$HOME/.local/bin/snappy-switcher"
  if [[ ! -x "$snappy_switcher" ]]; then
    snappy_switcher="$(command -v snappy-switcher 2>/dev/null || true)"
  fi
  if [[ -n "$snappy_switcher" ]]; then
    "$snappy_switcher" --reload-config >/dev/null 2>&1 || true
  fi
fi

rasi_wallpaper="${wallpaper//\\/\\\\}"
rasi_wallpaper="${rasi_wallpaper//\"/\\\"}"
cat > "$HOME/.cache/wal/tirbofish.rasi.tmp" <<EOF
* {
  wal-background:     $background;
  wal-background-alt: ${background}e6;
  wal-foreground:     $foreground;
  wal-selected:       $accent;
  wal-active:         $secondary;
  wal-urgent:         $danger;
  wal-tile-bg:        ${background}cc;
  wal-divider:        ${foreground}30;
  wal-wallpaper:      url("$rasi_wallpaper", width);
}
EOF
mv "$HOME/.cache/wal/tirbofish.rasi.tmp" "$HOME/.cache/wal/tirbofish.rasi"

cat > "$HOME/.cache/wal/tirbofish-hyprlock.conf.tmp" <<EOF
\$wal_background = rgba(${background#\#}ff)
\$wal_foreground = rgba(${foreground#\#}ff)
\$wal_foreground_dim = rgba(${foreground#\#}b3)
\$wal_accent = rgba(${accent#\#}ff)
\$wal_accent_dim = rgba(${accent#\#}cc)
\$wal_secondary = rgba(${secondary#\#}ff)
\$wal_danger = rgba(${danger#\#}ff)
\$wal_wallpaper = $wallpaper
EOF
mv "$HOME/.cache/wal/tirbofish-hyprlock.conf.tmp" "$HOME/.cache/wal/tirbofish-hyprlock.conf"

for dunst in "$HOME/.config/dunst/dunstrc" \
             "$HOME/.config/dunst/dunstrc_dark" \
             "$HOME/.config/dunst/dunstrc_light"; do
  if [[ ! -f "$dunst" ]]; then continue; fi
  awk -v bg="$background" -v fg="$foreground" -v accent="$accent" \
      -v secondary="$secondary" -v danger="$danger" '
    /^\[urgency_/ { section=$0 }
    section == "[urgency_low]" && $1 == "background"  { print "    background = \"" bg "\""; next }
    section == "[urgency_low]" && $1 == "foreground"  { print "    foreground = \"" fg "\""; next }
    section == "[urgency_low]" && $1 == "frame_color" { print "    frame_color = \"" secondary "\""; next }
    section == "[urgency_low]" && $1 == "highlight"   { print "    highlight = \"" accent "\""; next }
    section == "[urgency_normal]" && $1 == "background"  { print "    background = \"" bg "\""; next }
    section == "[urgency_normal]" && $1 == "foreground"  { print "    foreground = \"" fg "\""; next }
    section == "[urgency_normal]" && $1 == "frame_color" { print "    frame_color = \"" accent "\""; next }
    section == "[urgency_normal]" && $1 == "highlight"   { print "    highlight = \"" secondary "\""; next }
    section == "[urgency_critical]" && $1 == "background"  { print "    background = \"" danger "\""; next }
    section == "[urgency_critical]" && $1 == "foreground"  { print "    foreground = \"" bg "\""; next }
    section == "[urgency_critical]" && $1 == "frame_color" { print "    frame_color = \"" danger "\""; next }
    section == "[urgency_critical]" && $1 == "highlight"   { print "    highlight = \"" fg "\""; next }
    { print }
  ' "$dunst" > "$dunst.tmp"
  mv "$dunst.tmp" "$dunst"
done
systemctl --user try-restart dunst.service >/dev/null 2>&1 || true

legacy_theme="$HOME/.config/quickshell/theme.js"
if [[ -f "$legacy_theme" ]]; then
  sed -i \
    -e "s|^var bgPanel =.*|var bgPanel = \"${background}e0\"|" \
    -e "s|^var bgCard  =.*|var bgCard  = \"$background\"|" \
    -e "s|^var bgItem  =.*|var bgItem  = \"${muted}40\"|" \
    -e "s|^var bgItemHover =.*|var bgItemHover = \"${muted}70\"|" \
    -e "s|^var fgMain  =.*|var fgMain  = \"$foreground\"|" \
    -e "s|^var fgMuted =.*|var fgMuted = \"$muted\"|" \
    -e "s|^var fgOnAccent =.*|var fgOnAccent = \"$background\"|" \
    -e "s|^var accent =.*|var accent = \"$accent\"|" \
    -e "s|^var accentBlue =.*|var accentBlue = \"$secondary\"|" \
    -e "s|^var accentRed  =.*|var accentRed  = \"$danger\"|" \
    -e "s|^var weatherd=.*|var weatherd=\"$muted\"|" \
    -e "s|^var weatherl=.*|var weatherl=\"$secondary\"|" \
    "$legacy_theme"
fi

printf '%s\t%s\t%s\t%s\t%s\n' \
  "$background" "$foreground" "$accent" "$secondary" "$danger"
