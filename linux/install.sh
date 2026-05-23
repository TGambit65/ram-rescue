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

# ---------------------------------------------------------------- CLI
HOTKEY_ACCEL=""
DO_BIND_HOTKEY=0

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --bind-hotkey[=ACCEL]   After install, bind a GNOME keyboard shortcut to
                          launch the overlay (kill picker). ACCEL defaults to
                          "Super+R". Other examples: "Ctrl+Alt+R",
                          "Super+Escape", or raw GTK format like "<Super>r".
                          Currently GNOME-only — silently skipped elsewhere.
  -h, --help              This message
EOF
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --bind-hotkey)
        DO_BIND_HOTKEY=1
        HOTKEY_ACCEL="Super+R"
        ;;
      --bind-hotkey=*)
        DO_BIND_HOTKEY=1
        HOTKEY_ACCEL="${1#--bind-hotkey=}"
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        die "unknown flag: $1 (try --help)"
        ;;
    esac
    shift
  done
}

# Convert "Super+R" / "Ctrl+Alt+R" / "Super+Escape" → GTK accelerator format.
# Passes through anything already in <Modifier>key form.
normalize_accel() {
  local input="$1"
  if [[ "$input" == \<* ]]; then
    echo "$input"
    return
  fi
  local IFS='+'
  read -ra parts <<<"$input"
  local out="" i p last_idx
  last_idx=$((${#parts[@]} - 1))
  for i in "${!parts[@]}"; do
    p="${parts[$i]}"
    if ((i == last_idx)); then
      # Final key: single letter → lowercase; named keys (Escape, F1...) → as-is.
      if ((${#p} == 1)); then
        out+="${p,,}"
      else
        out+="$p"
      fi
    else
      case "${p,,}" in
        super | meta | win | windows) out+="<Super>" ;;
        ctrl | control)               out+="<Control>" ;;
        alt)                          out+="<Alt>" ;;
        shift)                        out+="<Shift>" ;;
        *)                            out+="<$p>" ;;
      esac
    fi
  done
  echo "$out"
}

# Bind a custom GNOME keyboard shortcut to `ram-rescue overlay`.
# Idempotent: re-running with a different accel just updates the existing
# ram-rescue entry; doesn't disturb other custom keybindings.
bind_hotkey() {
  local accel="$1"
  local normalized
  normalized=$(normalize_accel "$accel")

  case "${XDG_CURRENT_DESKTOP:-}" in
    *GNOME* | *Unity*) ;;
    *)
      warn "Hotkey binding via gsettings is only supported on GNOME-based desktops."
      warn "Bind '${LOCAL_BIN}/ram-rescue overlay' to a key manually via your DE's settings."
      return 0
      ;;
  esac

  if ! command -v gsettings >/dev/null 2>&1; then
    warn "gsettings not found — skipping hotkey binding."
    return 0
  fi

  local kb_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ram-rescue/"
  local schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$kb_path"

  # Append to the existing list of custom-keybinding paths if not already present.
  local current new_list
  current=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)
  if [[ "$current" == *"$kb_path"* ]]; then
    say "Hotkey path already registered — updating binding."
  else
    if [[ "$current" == "@as []" || "$current" == "[]" ]]; then
      new_list="['$kb_path']"
    else
      # current looks like "['path1', 'path2']" — strip trailing ']' and append.
      new_list="${current%]}, '$kb_path']"
    fi
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$new_list"
  fi

  gsettings set "$schema" name 'ram-rescue overlay'
  gsettings set "$schema" command "$LOCAL_BIN/ram-rescue overlay"
  gsettings set "$schema" binding "$normalized"

  say "Bound $normalized to 'ram-rescue overlay'."
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
parse_args "$@"
preflight
locate_source
install_files
activate
verify

if ((DO_BIND_HOTKEY)); then
  bind_hotkey "$HOTKEY_ACCEL"
fi

printf '\n\033[1;32mInstalled.\033[0m\n\n'
cat <<EOF
Quick test:        ram-rescue test
Show status:       ram-rescue status
Open kill picker:  ram-rescue overlay   (or your bound hotkey)
Tail logs:         ram-rescue logs
Configure:         \$EDITOR $CONFIG_DIR/config
Uninstall:         ram-rescue uninstall

EOF
