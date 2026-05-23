#!/usr/bin/env bash
# fake-low-mem.sh — force ram-rescue to fire an alert by spoofing MemAvailable.
# Useful for verifying notification, action buttons, and monitor launch.

set -euo pipefail

PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/ram-rescue"
SCRIPT="$PREFIX/ram-rescue"

if [[ ! -x "$SCRIPT" ]]; then
  # Fall back to running from the repo if ram-rescue isn't installed.
  SCRIPT=$(cd "$(dirname "$0")/.." && pwd)/bin/ram-rescue
fi

# 100 MB available — well below any sane threshold.
MEMAVAILABLE_OVERRIDE=100000 "$SCRIPT"
