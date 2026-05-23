#!/usr/bin/env bash
# ram-rescue uninstaller — equivalent to `ram-rescue uninstall` but standalone.

set -euo pipefail

PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/ram-rescue"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

say "Disabling and removing ram-rescue.timer..."
systemctl --user disable --now ram-rescue.timer 2>/dev/null || true
rm -f "$SYSTEMD_USER_DIR/ram-rescue.timer" "$SYSTEMD_USER_DIR/ram-rescue.service"
systemctl --user daemon-reload

say "Removing scripts..."
rm -rf "$PREFIX"
rm -f "$HOME/.local/bin/ram-rescue"

printf '\n\033[1;32mUninstalled.\033[0m\n\n'
cat <<EOF
Config and state preserved at:
  ${XDG_CONFIG_HOME:-$HOME/.config}/ram-rescue/
  ${XDG_STATE_HOME:-$HOME/.local/state}/ram-rescue/

Delete manually if desired.
EOF
