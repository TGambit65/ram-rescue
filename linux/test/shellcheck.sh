#!/usr/bin/env bash
# Run shellcheck on all shell scripts in the repo.

set -euo pipefail

cd "$(dirname "$0")/../.."

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck not installed. Install with: sudo apt install shellcheck" >&2
  exit 1
fi

files=(
  install.sh
  linux/bin/ram-rescue
  linux/bin/ram-rescue-ctl
  linux/install.sh
  linux/uninstall.sh
  linux/test/fake-low-mem.sh
  linux/test/shellcheck.sh
  macos/bin/ram-rescue
  macos/bin/ram-rescue-ctl
  macos/install.sh
  macos/uninstall.sh
)

echo "==> Running shellcheck on ${#files[@]} files..."
shellcheck --severity=warning "${files[@]}"
echo "==> All checks passed."
