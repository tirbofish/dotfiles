#!/usr/bin/env bash
# Run from hypridle after_sleep_cmd.
set -u

hyprctl dispatch 'hl.dsp.dpms({action = "on"})' >/dev/null 2>&1 || true
systemctl --user start rclone-zimaos.service >/dev/null 2>&1 || true
exit 0
