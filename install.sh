#!/usr/bin/env bash
# ram-rescue cross-platform installer dispatcher.
# Detects OS (uname) and forwards to the right platform installer.
# Windows users: run windows/install.ps1 directly with PowerShell.

set -euo pipefail

REPO_URL="https://github.com/TGambit65/ram-rescue"
BRANCH="${RAM_RESCUE_BRANCH:-main}"

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

uname_s=$(uname -s 2>/dev/null || echo unknown)

case "$uname_s" in
  Linux)
    PLATFORM="linux"
    ;;
  Darwin)
    PLATFORM="macos"
    ;;
  CYGWIN* | MINGW* | MSYS*)
    die "Detected Windows-like shell. Run windows/install.ps1 with PowerShell instead:
    powershell -ExecutionPolicy Bypass -File windows/install.ps1"
    ;;
  *)
    die "Unsupported platform: $uname_s. Supported: Linux, macOS, Windows (via PowerShell)."
    ;;
esac

say "Detected platform: $PLATFORM"

# Locate source: prefer current dir (cloned repo), else clone.
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [[ -d "$script_dir/$PLATFORM" && -x "$script_dir/$PLATFORM/install.sh" ]]; then
  say "Running $PLATFORM/install.sh from $script_dir..."
  exec "$script_dir/$PLATFORM/install.sh" "$@"
fi

# curl|bash mode — clone and exec.
if ! command -v git >/dev/null 2>&1; then
  die "git not found. Install git and retry, or clone the repo manually:
    git clone $REPO_URL && cd ram-rescue && ./install.sh"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
say "Cloning $REPO_URL@$BRANCH..."
git clone --depth=1 --branch "$BRANCH" "$REPO_URL" "$tmp/ram-rescue" >/dev/null
exec "$tmp/ram-rescue/$PLATFORM/install.sh" "$@"
