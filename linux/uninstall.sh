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

# Unbind hotkey if it was set by --bind-hotkey on install (GNOME-only, silent if absent).
KB_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ram-rescue/"
if command -v gsettings >/dev/null 2>&1; then
  CURRENT=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || echo "@as []")
  if [[ "$CURRENT" == *"$KB_PATH"* ]]; then
    say "Removing ram-rescue hotkey binding..."
    # Reset our specific keybinding's properties.
    gsettings reset-recursively "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KB_PATH" 2>/dev/null || true
    # Remove our path from the list, preserve others.
    NEW_LIST=$(echo "$CURRENT" | sed "s|, *'$KB_PATH'||g; s|'$KB_PATH', *||g; s|'$KB_PATH'||g; s|\[ *\]|@as []|")
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$NEW_LIST" 2>/dev/null || true
  fi
fi

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
