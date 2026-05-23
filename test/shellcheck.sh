#!/usr/bin/env bash
# Run shellcheck on all shell scripts in the repo.

set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck not installed. Install with: sudo apt install shellcheck" >&2
  exit 1
fi

files=(
  bin/ram-rescue
  bin/ram-rescue-ctl
  install.sh
  uninstall.sh
  test/fake-low-mem.sh
  test/shellcheck.sh
)

echo "==> Running shellcheck on ${#files[@]} files..."
shellcheck --severity=warning "${files[@]}"
echo "==> All checks passed."
