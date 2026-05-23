#!/usr/bin/env bash
set -euo pipefail

PREFIX="$HOME/Library/Application Support/ram-rescue"
LAUNCHAGENT_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.tgambit65.ram-rescue.plist"

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

say "Unloading launchd agent..."
launchctl unload "$LAUNCHAGENT_DIR/$PLIST_NAME" 2>/dev/null || true
rm -f "$LAUNCHAGENT_DIR/$PLIST_NAME"

say "Removing scripts..."
rm -rf "$PREFIX"
rm -f "$HOME/.local/bin/ram-rescue"

printf '\n\033[1;32mUninstalled.\033[0m\n\n'
echo "Config and state preserved. Delete manually if desired."
