#!/usr/bin/env bash
set -euo pipefail

root="$HOME/.config/themes"
state_dir="$HOME/.local/state/theme"
current_file="$state_dir/current_theme"
wallpaper_link="$state_dir/current_wallpaper"
kitty_startup="$state_dir/kitty_startup.conf"
fastfetch_logo="$state_dir/fastfetch_logo"
default_fastfetch_logo="$HOME/.config/fastfetch/fox1.png"
pywal="$HOME/.config/hypr/scripts/pywal.sh"
mode_script="$HOME/.config/quickshell/utils/theme-mode.sh"

mkdir -p "$root" "$state_dir"

resolve() {
  local pack="$1" rel="$2"
  [[ -z "$rel" || "$rel" == "null" ]] && return 1
  if [[ "$rel" == /* ]]; then
    [[ -f "$rel" ]] && { printf '%s' "$rel"; return 0; }
    return 1
  fi
  [[ -f "$pack/$rel" ]] && { printf '%s' "$pack/$rel"; return 0; }
  return 1
}

list() {
  python3 - <<'PY'
import json, os
from pathlib import Path
root = Path.home() / ".config/themes"
cur_file = Path.home() / ".local/state/theme/current_theme"
current = cur_file.read_text().strip() if cur_file.is_file() else ""
packs = []
if root.is_dir():
    for d in sorted(root.iterdir()):
        man = d / "theme.json"
        if not man.is_file():
            continue
        try:
            meta = json.loads(man.read_text())
        except Exception:
            continue
        def path(key):
            rel = meta.get(key) or ""
            if not rel:
                return ""
            p = Path(rel) if str(rel).startswith("/") else d / rel
            return str(p) if p.is_file() else ""
        packs.append({
            "id": d.name,
            "name": meta.get("name") or d.name,
            "mode": meta.get("mode") or "dark",
            "wallpaper": path("wallpaper"),
            "kittyStartup": path("kittyStartup"),
            "active": d.name == current,
        })
print(json.dumps(packs))
PY
}

write_cache() {
  mkdir -p "$HOME/.cache/quickshell"
  list > "$HOME/.cache/quickshell/theme-packs.json"
}

current() {
  if [[ -f "$current_file" ]]; then cat "$current_file"; else echo ""; fi
}

write_kitty() {
  printf 'background_image none\n' > "$kitty_startup"
  kill -USR1 $(pidof kitty) >/dev/null 2>&1 || true
}

write_fastfetch() {
  local img="${1:-}"
  if [[ -z "$img" || ! -f "$img" ]]; then
    img="$default_fastfetch_logo"
  fi
  if [[ -f "$img" ]]; then
    ln -sfn "$img" "$fastfetch_logo"
  fi
}

apply() {
  local id="${1:-}"
  local pack="$root/$id"
  local man="$pack/theme.json"
  [[ -f "$man" ]] || { echo "unknown theme: $id" >&2; exit 1; }

  local mode wallpaper kitty_img
  mode="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("mode") or "dark")' "$man")"
  wallpaper="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("wallpaper") or "")' "$man")"
  kitty_img="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("kittyStartup") or "")' "$man")"

  local wall_path kitty_path
  wall_path="$(resolve "$pack" "$wallpaper" || true)"
  kitty_path="$(resolve "$pack" "$kitty_img" || true)"

  if [[ "$mode" == "light" || "$mode" == "dark" ]]; then
    "$mode_script" "$mode" --quiet --no-wallpaper >/dev/null 2>&1 || true
  fi

  if [[ -n "$wall_path" ]]; then
    ln -sfn "$wall_path" "$wallpaper_link"
    command -v awww >/dev/null && awww img "$wall_path" >/dev/null 2>&1 || true
    "$pywal" "$wall_path" "$mode" >/dev/null 2>&1 || true
  fi

  write_kitty
  write_fastfetch "$kitty_path"
  printf '%s' "$id" > "$current_file"
  echo "$id"
}

case "${1:-list}" in
  list) list ;;
  current) current ;;
  apply) apply "${2:-}" ;;
  *) echo "usage: theme.sh list|current|apply <id>" >&2; exit 1 ;;
esac
