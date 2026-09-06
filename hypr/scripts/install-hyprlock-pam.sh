#!/usr/bin/env bash
# Installs the hyprlock PAM files (password-only hyprlock + biopass helper service).
set -euo pipefail
install -m 644 /home/tirbofish/.config/hypr/pam.d/hyprlock /etc/pam.d/hyprlock
install -m 644 /home/tirbofish/.config/hypr/pam.d/hyprlock-biopass /etc/pam.d/hyprlock-biopass
echo "Installed /etc/pam.d/hyprlock and /etc/pam.d/hyprlock-biopass"
