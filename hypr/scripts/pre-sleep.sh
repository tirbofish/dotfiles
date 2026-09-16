#!/usr/bin/env bash
# Run from hypridle before_sleep_cmd. Lock without Biopass, then drop the
# rclone FUSE mount so vicinae-file-indexer cannot sit in D-state and abort
# s2idle with EBUSY.
set -u

RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
SKIP="$RUNTIME/hyprlock-skip-biopass"
ARMED="$RUNTIME/hyprlock-biopass.armed"
TRIGGER="$RUNTIME/hyprlock-biopass.trigger"
LOCKDIR="$RUNTIME/hyprlock-biopass.lock"
ZIMA="${HOME}/ZimaOS"

: >"$SKIP"
rm -f "$ARMED" "$TRIGGER"
rmdir "$LOCKDIR" 2>/dev/null || true
pkill -f '/hyprlock-biopass-auth( |$)' 2>/dev/null || true
pkill -f '/hyprlock-biopass\.sh window' 2>/dev/null || true

loginctl lock-session >/dev/null 2>&1 || true

for _ in $(seq 1 20); do
  pidof hyprlock >/dev/null 2>&1 && break
  sleep 0.05
done

timeout 2 systemctl --user stop rclone-zimaos.service >/dev/null 2>&1 || true
if mountpoint -q "$ZIMA" 2>/dev/null; then
  fusermount3 -uz "$ZIMA" >/dev/null 2>&1 || umount -l "$ZIMA" >/dev/null 2>&1 || true
fi

exit 0
