#!/usr/bin/env bash
# ram-rescue installer
# Usage: ./install.sh
# Or:    curl -fsSL https://raw.githubusercontent.com/TGambit65/ram-rescue/main/install.sh | bash

set -euo pipefail

REPO_URL="https://github.com/TGambit65/ram-rescue"
BRANCH="${RAM_RESCUE_BRANCH:-main}"

PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/ram-rescue"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ram-rescue"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
LOCAL_BIN="$HOME/.local/bin"

# ---------------------------------------------------------------- helpers
say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

# ---------------------------------------------------------------- preflight
preflight() {
  say "Preflight checks..."
  require_cmd awk
  require_cmd ps
  require_cmd systemctl
  require_cmd logger
  require_cmd notify-send

  if ! systemctl --user show-environment >/dev/null 2>&1; then
    die "systemctl --user is not available (is this a desktop session?)"
  fi

  case "${XDG_CURRENT_DESKTOP:-}" in
    *GNOME* | *Unity* | *Cinnamon* | *KDE* | *Plasma* | *XFCE* | *MATE*)
      say "Desktop detected: $XDG_CURRENT_DESKTOP"
      ;;
    "")
      warn "XDG_CURRENT_DESKTOP is empty — monitor launch will fall back to terminal+htop."
      ;;
    *)
      warn "Unrecognized desktop: $XDG_CURRENT_DESKTOP — monitor launch will fall back to terminal+htop."
      ;;
  esac

  if [[ "${XDG_CURRENT_DESKTOP:-}" == *XFCE* ]]; then
    warn "XFCE's notification daemon may not show action buttons. Body text will include a fallback hint."
  fi
}

# ---------------------------------------------------------------- locate source files
locate_source() {
  # If running from a cloned repo, use ./bin and ./systemd directly.
  local script_dir
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  if [[ -f "$script_dir/bin/ram-rescue" && -f "$script_dir/systemd/ram-rescue.timer.in" ]]; then
    SRC_DIR="$script_dir"
    return
  fi

  # Otherwise (curl|bash mode), clone the repo to a temp dir.
  require_cmd git
  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  say "Cloning $REPO_URL@$BRANCH..."
  git clone --depth=1 --branch "$BRANCH" "$REPO_URL" "$tmp/ram-rescue" >/dev/null
  SRC_DIR="$tmp/ram-rescue/linux"
}

# ---------------------------------------------------------------- install
install_files() {
  say "Installing to $PREFIX..."
  mkdir -p "$PREFIX" "$CONFIG_DIR" "$SYSTEMD_USER_DIR" "$LOCAL_BIN"
  install -m755 "$SRC_DIR/bin/ram-rescue" "$PREFIX/ram-rescue"
  install -m755 "$SRC_DIR/bin/ram-rescue-ctl" "$PREFIX/ram-rescue-ctl"
  install -m755 "$SRC_DIR/bin/ram-rescue-overlay" "$PREFIX/ram-rescue-overlay"
  install -m644 "$SRC_DIR/lib/classify.sh" "$PREFIX/classify.sh"
  ln -sf "$PREFIX/ram-rescue-ctl" "$LOCAL_BIN/ram-rescue"

  # Render systemd templates with @PREFIX@ substitution.
  sed "s|@PREFIX@|$PREFIX|g" "$SRC_DIR/systemd/ram-rescue.service.in" \
    >"$SYSTEMD_USER_DIR/ram-rescue.service"
  cp "$SRC_DIR/systemd/ram-rescue.timer.in" "$SYSTEMD_USER_DIR/ram-rescue.timer"

  # Seed config only if missing — never overwrite user customizations.
  if [[ ! -f "$CONFIG_DIR/config" ]]; then
    cp "$SRC_DIR/../config.example.sh" "$CONFIG_DIR/config"
    say "Seeded default config at $CONFIG_DIR/config"
  else
    say "Existing config preserved at $CONFIG_DIR/config"
  fi
}

# ---------------------------------------------------------------- activate
activate() {
  say "Reloading systemd-user and enabling timer..."
  systemctl --user daemon-reload
  systemctl --user enable --now ram-rescue.timer
}

# ---------------------------------------------------------------- verify
verify() {
  if systemctl --user is-active --quiet ram-rescue.timer; then
    say "Timer active. Next run in 90s after boot or 60s after last run."
  else
    die "Timer failed to activate. Run: systemctl --user status ram-rescue.timer"
  fi

  # Check that $HOME/.local/bin is on PATH; warn if not.
  case ":$PATH:" in
    *":$LOCAL_BIN:"*) ;;
    *) warn "$LOCAL_BIN is not on PATH — add it to your shell rc to use 'ram-rescue' from the command line." ;;
  esac
}

# ---------------------------------------------------------------- main
preflight
locate_source
install_files
activate
verify

printf '\n\033[1;32mInstalled.\033[0m\n\n'
cat <<EOF
Quick test:        ram-rescue test
Show status:       ram-rescue status
Tail logs:         ram-rescue logs
Configure:         \$EDITOR $CONFIG_DIR/config
Uninstall:         ram-rescue uninstall

EOF
