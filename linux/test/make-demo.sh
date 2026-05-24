#!/usr/bin/env bash
# make-demo.sh — automate ram-rescue demo state for screenshots / GIF recording.
#
# `hero`  fires one alert at ~12% available so you can screenshot the
#         notification for a README hero image.
# `gif`   walks through a recordable demo: shows `ram-rescue why`, fires the
#         alert, hands off to you to press the hotkey and interact with the
#         kill picker. Records in real time; you bring the screen recorder.
# `check` verifies prerequisites.
# `clean` clears any snooze the demo left behind.
#
# The top-apps list shown in the alert is real (your current `ps` output);
# only the memory percentage is spoofed via MEMAVAILABLE_OVERRIDE.

set -euo pipefail

RAM_RESCUE_BIN="${RAM_RESCUE_BIN:-$HOME/.local/share/ram-rescue/ram-rescue}"
RAM_RESCUE_CLI="${RAM_RESCUE_CLI:-$HOME/.local/bin/ram-rescue}"

# Target ~12% available (yellow severity, dramatic but believable).
calc_override_kb() {
  local total pct=${1:-12}
  total=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
  echo $((total * pct / 100))
}

usage() {
  cat <<'EOF'
make-demo.sh — set up demo state for ram-rescue screenshots / GIFs.

Usage: make-demo.sh <mode> [percent]

Modes:
  hero [PCT]   Fire one alert at PCT% available (default 12) for a still
               screenshot. Notification stays visible for ~45s.

  gif [PCT]    Scripted demo flow for recording an animated GIF:
                 (1) prints `ram-rescue why` output
                 (2) waits 3s
                 (3) fires the notification
                 (4) hands off — you press Ctrl+Alt+R, interact with the
                     kill picker, and stop your recording when done.

  check        Verify ram-rescue installed + report available recorders.
  clean        Clear ram-rescue snooze state (run after demos).
  help         This message.

Recommended recorders:
  Wayland:   kooha   (sudo apt install kooha)
  X11:       peek    (sudo apt install peek)
  Either:    obs-studio (heavier, more control)
  Stills:    flameshot or gnome-screenshot

Examples:
  make-demo.sh check
  make-demo.sh hero          # default 12% available
  make-demo.sh hero 5        # red severity (5% available)
  make-demo.sh gif
  make-demo.sh clean
EOF
}

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

check_prereqs() {
  [[ -x "$RAM_RESCUE_BIN" ]] || die "ram-rescue not installed at $RAM_RESCUE_BIN (run install.sh first)"
  say "ram-rescue: $RAM_RESCUE_BIN"

  echo ""
  echo "Available recording / screenshot tools:"
  local found=0
  for tool in peek kooha obs flameshot gnome-screenshot spectacle xfce4-screenshooter scrot grim slurp; do
    if command -v "$tool" >/dev/null 2>&1; then
      printf '  ✓ %s\n' "$tool"
      found=1
    fi
  done
  ((found == 0)) && warn "No screen recorder / screenshot tool detected. Try: sudo apt install flameshot peek"

  echo ""
  echo "Notification daemon:"
  if pgrep -f 'notification|gsd-notif|notification-daemon|dunst' >/dev/null 2>&1; then
    say "running"
  else
    warn "no obvious notification daemon — alerts may not render"
  fi

  echo ""
  echo "Memory snapshot:"
  local total avail pct
  total=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
  avail=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
  pct=$((avail * 100 / total))
  printf '  %d%% available (%d MB / %d MB)\n' "$pct" "$((avail/1024))" "$((total/1024))"
}

mode_hero() {
  local pct=${1:-12}
  local override
  override=$(calc_override_kb "$pct")

  cat <<EOF

=========================================================
                   HERO SCREENSHOT MODE
=========================================================

About to fire an alert at ~${pct}% available, showing your
real top apps. Notification will stay visible ~30s.

Before pressing ENTER:
  1. Open your screenshot tool (flameshot / gnome-screenshot
     -a / spectacle) and have it ready for area selection.
  2. Make sure notifications are unmuted in Do Not Disturb.

After pressing ENTER:
  5-second countdown, then alert fires.

EOF
  read -rp "Press ENTER when ready (Ctrl+C to cancel)..."

  "$RAM_RESCUE_CLI" unsnooze >/dev/null 2>&1 || true

  for n in 5 4 3 2 1; do
    printf '\r  %s ' "$n"
    sleep 1
  done
  echo ""

  MEMAVAILABLE_OVERRIDE="$override" "$RAM_RESCUE_BIN" &
  local alert_pid=$!
  say "Notification fired (PID $alert_pid). Screenshot it now."
  echo "    Suggested crops:"
  echo "      flameshot gui          # interactive area select"
  echo "      gnome-screenshot -a    # interactive area select"
  echo ""
  echo "Will wait up to 45s for the notification lifecycle to end."
  wait "$alert_pid" 2>/dev/null || true
  echo ""
  say "Done. Run: $0 clean"
}

mode_gif() {
  local pct=${1:-12}
  local override
  override=$(calc_override_kb "$pct")

  cat <<EOF

=========================================================
                  DEMO GIF RECORDING MODE
=========================================================

Storyboard (~12-15 seconds total):

  0:00-0:03   Terminal shows 'ram-rescue why' output
  0:03-0:04   Notification slides in
  0:04-0:07   Notification body visible (user reads)
  0:07-0:08   You press Ctrl+Alt+R
  0:08-0:12   Kill picker opens, you tick an app, click OK
  0:12-0:14   "Sent SIGTERM to N processes" success

Before pressing ENTER:
  1. Start your screen recorder.
     * Region should cover BOTH this terminal AND the area
       where desktop notifications appear (usually top-right).
     * Suggested: peek, kooha, or obs-studio.
  2. Make sure the kill-picker hotkey (Ctrl+Alt+R) is bound:
       gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ram-rescue/ binding
     If empty, run: ./linux/install.sh --bind-hotkey

EOF
  read -rp "Press ENTER once your recorder is running..."

  "$RAM_RESCUE_CLI" unsnooze >/dev/null 2>&1 || true

  clear
  echo '$ ram-rescue why'
  echo ""
  "$RAM_RESCUE_CLI" why
  echo ""
  printf '(notification fires in 3s — get ready to hit Ctrl+Alt+R when it appears)\n'
  sleep 3

  MEMAVAILABLE_OVERRIDE="$override" "$RAM_RESCUE_BIN" &
  local alert_pid=$!

  echo ""
  printf '\033[1;33m→ NOTIFICATION FIRED.\033[0m  Press Ctrl+Alt+R now.\n'
  printf '   Tick an app in the kill picker, click OK.\n'
  printf '   Stop your recording when the success dialog appears.\n'
  echo ""
  echo "(this script will wait up to 45s for the alert lifecycle)"

  wait "$alert_pid" 2>/dev/null || true

  echo ""
  say "Alert process exited. Stop recording if you haven't already."
  say "Convert recording to GIF if needed:"
  echo "    ffmpeg -i recording.mp4 -vf 'fps=12,scale=900:-1:flags=lanczos' -loop 0 demo.gif"
  echo ""
  say "Then: $0 clean"
}

mode_clean() {
  "$RAM_RESCUE_CLI" unsnooze >/dev/null 2>&1 || true
  say "Cleared snooze state. Timer continues normally."
}

case "${1:-help}" in
  hero)   shift; check_prereqs >/dev/null; mode_hero "${1:-12}" ;;
  gif)    shift; check_prereqs >/dev/null; mode_gif "${1:-12}" ;;
  check)  check_prereqs ;;
  clean)  mode_clean ;;
  help | --help | -h | "") usage ;;
  *)      echo "Unknown mode: $1" >&2; usage >&2; exit 1 ;;
esac
