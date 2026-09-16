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
surface="$(jq -r '.colors.color0' "$colors")"
wallpaper="$(jq -r '.wallpaper' "$colors")"
bg="${background#\#}"
fg="${foreground#\#}"
ac="${accent#\#}"
se="${secondary#\#}"
dn="${danger#\#}"
mu="${muted#\#}"
sf="${surface#\#}"

rgb_dec() {
  local h="${1#\#}"
  printf '%d, %d, %d' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))"
}

# Lift the wallpaper background toward the foreground so notification
# chrome matches shell cards instead of a flat special.background hole.
card="$(python3 -c "
def rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
a, b = rgb('$background'), rgb('$foreground')
t = 0.14
print('#' + ''.join(f'{round(a[i]*(1-t)+b[i]*t):02x}' for i in range(3)))
")"
card_fill="${card}ee"

settings="$HOME/.config/quickshell/lib/usersettings.json"
theme_id="$(cat "$HOME/.local/state/theme/current_theme" 2>/dev/null || true)"
theme_settings="$HOME/.config/themes/$theme_id/settings.json"
for settings in "$settings" "$theme_settings"; do
  [[ -f "$settings" ]] || continue
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
done

mkdir -p "$HOME/.config/hypremoji"
cat > "$HOME/.config/hypremoji/style.css" <<EOF
:root {
    --primary-col: ${accent};
    --primary-col-glow: ${accent}aa;
    --gray: ${muted};
    --bg-col: ${background};
    --input-text-col: ${foreground};
    --btn-list-col: ${background};
    --entry-unfocus: ${danger};
    --btn-list-col-hover: ${secondary};
    --btn-list-col-hover-glow: ${secondary}77;
    --btn-nav-col: ${muted};
    --btn-nav-col-hover: ${background};
    --emoji-font: "Noto Color Emoji";
}
EOF

cat > "$HOME/.cache/wal/tirbofish-hyprland.lua.tmp" <<EOF
return {
  active_border = { colors = { "rgba(${ac}ee)", "rgba(${se}ee)" }, angle = 45 },
  inactive_border = "rgba(${bg}aa)",
  accent = "rgb(${ac})",
  secondary = "rgb(${se})",
  background = "rgb(${bg})",
  foreground = "rgb(${fg})",
  danger = "rgb(${dn})",
  muted = "rgb(${mu})",
  shadow = "rgba(${bg}44)"
}
EOF
mv "$HOME/.cache/wal/tirbofish-hyprland.lua.tmp" "$HOME/.cache/wal/tirbofish-hyprland.lua"

cat > "$HOME/.config/hypr/hyprtoolkit.conf.tmp" <<EOF
background = rgb($(rgb_dec "$background"))
base = rgb($(rgb_dec "$surface"))
text = rgb($(rgb_dec "$foreground"))
alternate_base = rgb($(rgb_dec "$muted"))
bright_text = rgb($(rgb_dec "$foreground"))
link_text = rgb($(rgb_dec "$accent"))
accent = rgb($(rgb_dec "$accent"))
accent_secondary = rgb($(rgb_dec "$secondary"))

rounding_large = 12
rounding_small = 8

h1_size = 19
h2_size = 15
h3_size = 13
font_size = 12
small_font_size = 10
font_family = Manrope
font_family_monospace = JetBrainsMono Nerd Font
EOF
mv "$HOME/.config/hypr/hyprtoolkit.conf.tmp" "$HOME/.config/hypr/hyprtoolkit.conf"

hyprctl eval "hl.config({
  general = {
    [\"col.active_border\"] = {
      colors = { \"rgba(${ac}ee)\", \"rgba(${se}ee)\" }, angle = 45
    },
    [\"col.inactive_border\"] = \"rgba(${bg}aa)\"
  },
  decoration = {
    shadow = { color = \"rgba(${bg}44)\" }
  },
  group = {
    groupbar = {
      [\"col.active\"] = \"rgb(${ac})\",
      [\"col.inactive\"] = \"rgb(${bg})\",
      text_color = \"rgb(${bg})\",
      text_color_inactive = \"rgb(${fg})\"
    }
  }
})" >/dev/null 2>&1 || true
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
\$wal_background = rgba(${bg}ff)
\$wal_foreground = rgba(${fg}ff)
\$wal_foreground_dim = rgba(${fg}b3)
\$wal_accent = rgba(${ac}ff)
\$wal_accent_dim = rgba(${ac}cc)
\$wal_secondary = rgba(${se}ff)
\$wal_danger = rgba(${dn}ff)
\$wal_dim = rgba(${bg}b3)
\$wal_shadow = rgba(${bg}80)
\$wal_wallpaper = $wallpaper
EOF
mv "$HOME/.cache/wal/tirbofish-hyprlock.conf.tmp" "$HOME/.cache/wal/tirbofish-hyprlock.conf"

for dunst in "$HOME/.config/dunst/dunstrc" \
             "$HOME/.config/dunst/dunstrc_dark" \
             "$HOME/.config/dunst/dunstrc_light"; do
  if [[ ! -f "$dunst" ]]; then continue; fi
  awk -v bg="$card_fill" -v fg="$foreground" -v accent="$accent" \
      -v muted="$muted" -v danger="$danger" '
    /^\[urgency_/ { section=$0 }
    section == "[urgency_low]" && $1 == "background"  { print "    background = \"" bg "\""; next }
    section == "[urgency_low]" && $1 == "foreground"  { print "    foreground = \"" fg "\""; next }
    section == "[urgency_low]" && $1 == "frame_color" { print "    frame_color = \"" muted "\""; next }
    section == "[urgency_low]" && $1 == "highlight"   { print "    highlight = \"" accent "\""; next }
    section == "[urgency_normal]" && $1 == "background"  { print "    background = \"" bg "\""; next }
    section == "[urgency_normal]" && $1 == "foreground"  { print "    foreground = \"" fg "\""; next }
    section == "[urgency_normal]" && $1 == "frame_color" { print "    frame_color = \"" accent "\""; next }
    section == "[urgency_normal]" && $1 == "highlight"   { print "    highlight = \"" accent "\""; next }
    section == "[urgency_critical]" && $1 == "background"  { print "    background = \"" bg "\""; next }
    section == "[urgency_critical]" && $1 == "foreground"  { print "    foreground = \"" fg "\""; next }
    section == "[urgency_critical]" && $1 == "frame_color" { print "    frame_color = \"" danger "\""; next }
    section == "[urgency_critical]" && $1 == "highlight"   { print "    highlight = \"" danger "\""; next }
    { print }
  ' "$dunst" > "$dunst.tmp"
  mv "$dunst.tmp" "$dunst"
done
if ! dunstctl reload >/dev/null 2>&1; then
  if systemctl --user is-active --quiet dunst.service; then
    systemctl --user restart dunst.service >/dev/null 2>&1 || true
  else
    killall dunst >/dev/null 2>&1 || true
    sleep 0.2
    dunst >/dev/null 2>&1 &
  fi
fi

python3 "$HOME/.config/hypr/scripts/vscode-wal.py" "$colors" "$mode" >/dev/null 2>&1 || true

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
