#!/usr/bin/env bash
# ram-rescue installer (macOS)

set -euo pipefail

REPO_URL="https://github.com/TGambit65/ram-rescue"
BRANCH="${RAM_RESCUE_BRANCH:-main}"

PREFIX="$HOME/Library/Application Support/ram-rescue"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ram-rescue"
LAUNCHAGENT_DIR="$HOME/Library/LaunchAgents"
LOCAL_BIN="$HOME/.local/bin"
PLIST_NAME="com.tgambit65.ram-rescue.plist"

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

preflight() {
  say "Preflight checks..."
  require_cmd osascript
  require_cmd sysctl
  require_cmd vm_stat
  require_cmd launchctl
  require_cmd awk
  require_cmd ps
}

locate_source() {
  local script_dir
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  if [[ -f "$script_dir/bin/ram-rescue" && -f "$script_dir/launchd/$PLIST_NAME.in" ]]; then
    SRC_DIR="$script_dir"
    return
  fi
  require_cmd git
  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  say "Cloning $REPO_URL@$BRANCH..."
  git clone --depth=1 --branch "$BRANCH" "$REPO_URL" "$tmp/ram-rescue" >/dev/null
  SRC_DIR="$tmp/ram-rescue/macos"
}

install_files() {
  say "Installing to $PREFIX..."
  mkdir -p "$PREFIX" "$CONFIG_DIR" "$LAUNCHAGENT_DIR" "$LOCAL_BIN"

  install -m755 "$SRC_DIR/bin/ram-rescue" "$PREFIX/ram-rescue"
  install -m755 "$SRC_DIR/bin/ram-rescue-ctl" "$PREFIX/ram-rescue-ctl"
  ln -sf "$PREFIX/ram-rescue-ctl" "$LOCAL_BIN/ram-rescue"

  sed "s|@PREFIX@|$PREFIX|g" "$SRC_DIR/launchd/$PLIST_NAME.in" >"$LAUNCHAGENT_DIR/$PLIST_NAME"

  if [[ ! -f "$CONFIG_DIR/config" ]]; then
    cp "$SRC_DIR/../config.example.sh" "$CONFIG_DIR/config"
    say "Seeded default config at $CONFIG_DIR/config"
  fi
}

activate() {
  say "Loading launchd agent..."
  # Unload first in case of stale registration.
  launchctl unload "$LAUNCHAGENT_DIR/$PLIST_NAME" 2>/dev/null || true
  launchctl load "$LAUNCHAGENT_DIR/$PLIST_NAME"
}

verify() {
  if launchctl list | grep -q "com.tgambit65.ram-rescue"; then
    say "Agent loaded. First run on load; then every 60s."
  else
    die "Agent failed to load. Run: launchctl load $LAUNCHAGENT_DIR/$PLIST_NAME"
  fi
  case ":$PATH:" in
    *":$LOCAL_BIN:"*) ;;
    *) warn "$LOCAL_BIN is not on PATH — add it to your shell rc to use 'ram-rescue' from the command line." ;;
  esac
}

preflight
locate_source
install_files
activate
verify

printf '\n\033[1;32mInstalled.\033[0m\n\n'
cat <<EOF
Quick test:        ram-rescue test
Show status:       ram-rescue status
Configure:         \$EDITOR $CONFIG_DIR/config
Uninstall:         ram-rescue uninstall

NOTE: First time you run \`ram-rescue test\`, macOS may prompt to grant
Script Editor / Terminal permission to send notifications. Allow it in
System Settings → Notifications & Focus.
EOF
