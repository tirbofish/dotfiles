#!/usr/bin/env bash
# Installs the hyprlock PAM files (password-only hyprlock + biopass helper service).
set -euo pipefail
pam_dir="$(dirname -- "$0")/../pam.d"
install -m 644 "$pam_dir"/hyprlock /etc/pam.d/hyprlock
install -m 644 "$pam_dir"/hyprlock-biopass /etc/pam.d/hyprlock-biopass
echo "Installed /etc/pam.d/hyprlock and /etc/pam.d/hyprlock-biopass"
