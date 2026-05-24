# Changelog

All notable changes to ram-rescue will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.5.0] — 2026-05-23

Four new triggers / commands designed to catch the cases the v0.4.x flow misses or to explain what's going on.

### Added — triggers
- **PSI-based trigger** (kernel ≥ 4.20). Reads `some avg10` from `/proc/pressure/memory`. If memory pressure exceeds `PSI_AVG10_THRESHOLD` (default `10.0`%), fires an alert *regardless of MemAvailable %*. This catches swap-thrashing situations where you technically have "free" RAM but the kernel is stalled. Set the threshold to `0` to disable. Title reads "Memory pressure" instead of "Low memory" so you can tell the triggers apart.
- **OOM-killer post-mortem**. Each timer fire now scans `journalctl -k` for kernel OOM events since the last check. If the kernel killed something while you were AFK, a separate `💀 Linux OOM-killer fired · victim: <name>` notification surfaces it. State tracked in `~/.local/state/ram-rescue/last-oom-check` so we don't double-notify. Toggle with `OOM_WATCH=0` in config.

### Added — analytical commands
- **`ram-rescue why`**: per-app analysis with "closing X frees Y" math, % of total RAM, process count, browser tab proxy. Includes a PSI summary line so you can tell at a glance whether the kernel agrees you're under pressure.
- **`ram-rescue stats [DAYS]`** (default 7): historical view from journald — alerts per day, most-frequently-flagged apps, alert outcomes (open/snooze/none), and OOM events surfaced.

### Changed
- Alert log line now includes `trigger=mem|psi` and `top=Chrome,Python,...` (top 3 app names). Old log lines from v0.4.x lack the `top=` field; `stats` shows a hint when no data is available yet.
- Notification title now reflects trigger: `🟡 Low memory · 12% available` vs `🟡 Memory pressure · 30% available (kernel stalling)`.
- Config gains two knobs: `PSI_AVG10_THRESHOLD` and `OOM_WATCH`.

### Implementation notes
- New helpers in `linux/lib/classify.sh`: `read_psi_avg10`, `psi_under_pressure`, `recent_oom_kills`, `oom_extract_victim`. Shared by all Linux entry points.
- macOS and Windows variants are *not* feature-parity in this release: PSI is Linux-only, and OOM detection uses Linux-specific `journalctl -k`. The macOS equivalent (`log show`) and Windows Event Log integration are tracked for v0.5.1+.

## [0.4.2] — 2026-05-23

Hotkey default changed from `Super+R` to `Ctrl+Alt+R`.

### Fixed
- **`--bind-hotkey` default**: Super+R turned out to be unreliable on GNOME because the "overlay key" (Super alone) opens the Activities overview with the search field focused. Pressing Super+R fast often registers as Super → overview opens → R types into the search box, *before* the custom Super+R shortcut is recognized. Verified the failure on Ubuntu 24 + GNOME 46 + X11. Any Super+letter combo where the letter starts common app names has the same issue.
- New default: `Ctrl+Alt+R`. Three-key chord that GNOME never pre-processes — fires every time.
- Help text and README now explicitly warn against Super+letter combos on GNOME and recommend chords or unused keys (`Pause`, function keys, `Super+Escape`) instead.

## [0.4.1] — 2026-05-23

`--bind-hotkey` flag on the Linux installer — set up the overlay keyboard shortcut without leaving the terminal.

### Added
- **`./linux/install.sh --bind-hotkey[=ACCEL]`**: binds a GNOME custom keyboard shortcut to `ram-rescue overlay`. `ACCEL` defaults to `Super+R`. Accepts human-friendly forms (`Super+R`, `Ctrl+Alt+R`, `Super+Escape`) or raw GTK accelerator format (`<Super>r`, `<Control><Alt>r`). The top-level dispatcher `install.sh` forwards the flag through.
- Hotkey binding via `gsettings` is idempotent: re-running with a different accel updates the existing entry without duplicating, and other custom keybindings are preserved.
- Uninstall (both `ram-rescue uninstall` and `linux/uninstall.sh`) now removes the hotkey entry from `custom-keybindings` and resets its properties — no dangling shortcut left behind.

### Notes
- GNOME / Unity only. On KDE / XFCE / MATE the flag prints a warning and skips silently (those DEs have their own hotkey systems; binding via shell is harder to do reliably).
- The "Bind locally now" gsettings recipe used in v0.4.0 prep still works for ad-hoc / non-installer use.

## [0.4.0] — 2026-05-23

Hotkey-launched kill picker (Linux). Prototype using zenity.

### Added
- **`ram-rescue overlay`**: on-demand zenity checklist showing all running apps grouped by name (same classifier as the notification). User ticks apps to kill, confirms, and SIGTERM is sent to each matching process. Closes itself when done.
- **Shared classifier library** at `linux/lib/classify.sh`: `classify_app`, `count_chrome_tabs`, `severity_emoji`, `build_app_table`, `format_size`. Sourced by both `ram-rescue` and `ram-rescue-overlay` so adding new app patterns only needs one edit.
- README documents the GNOME keyboard-shortcut binding (`Settings → Keyboard → Custom Shortcuts → command: ram-rescue overlay`).

### Footprint (honest measurement, Ubuntu 24 + GNOME 46)
- **Resident: 0 MB** (no daemon between invocations).
- **Visible: ~200 MB** when the overlay is open. Zenity 4.x in Ubuntu 24 pulls in GTK4 + GSK + Cairo + Pango + ~100 shared libraries — heavier than the 5-15 MB initially estimated. For reference, `gnome-system-monitor` (what "Open Monitor" launches) is ~215 MB visible, so the overlay is in the same tier as the existing flow.

### Known limitations / planned for v0.4.1
- Linux-only. macOS will need `osascript choose from list`; Windows will need `Out-GridView`.
- Tkinter alternative would drop visible cost to ~20 MB. Tracked.

## [0.3.0] — 2026-05-23

App grouping + visual refresh. The notification now shows top *apps* (not raw processes), each with an emoji indicator, a one-line summary, and — for browsers — an approximate tab count.

### Added
- **App classifier**: `classify_app` (bash on Linux/macOS, `switch -Regex` on Windows) maps process names to a known-apps catalog. Currently covers ~40 common apps (browsers, editors, AI tools, chat, media, runtimes, databases, system services). Unknown processes pass through with their raw name and 📦 emoji.
- **App-grouped top view**: `top_apps` aggregates RSS by app (e.g., all `chrome` processes roll up to "Chrome"; all `Code Helper` variants roll up to "VS Code"). Top 5 apps display with emoji + name + size + summary.
- **Browser tab proxy**: Chrome (and Chromium/Brave) shows an approximate tab count, derived from counting renderer-type processes that aren't extensions. macOS uses `Google Chrome Helper` process counts; Windows reads `CommandLine` from `Win32_Process`.
- **Severity emoji in title**: 🟡 (15–25% available), 🟠 (5–15%), 🔴 (<5%). Gives an instant visual read on how bad it is.
- **`ram-rescue apps` CLI subcommand**: prints the grouped top-apps view to stdout, no notification. Useful for testing and ad-hoc inspection.
- **Kernel threads filtered out**: processes with RSS=0 (kernel workers like `kthreadd`, `kworker/*`, `UVM global queue`) are dropped before aggregation.

### Changed
- Notification body redesigned: header line shows free/total MB; app rows use `EMOJI · Name · Size · Description` with a middle-dot separator for cleaner rendering in proportional fonts.
- Linux `ps -eo comm,rss` swapped to `ps -eo rss,comm` so multi-word `comm` values (kernel threads, wrapped npm commands) parse correctly.

### Fixed
- Post-increment in bash arithmetic (`((count++))`) returns 0 when count was 0, which `set -e` treats as failure — replaced with `count=$((count + 1))`.
- `set -u` + `${arr[key]:-0}` interaction in bash 5.2: associative-array element lookup with default fallback could trip nounset under certain conditions. The `top_apps` loop now disables `set -u` for its body and re-enables after.

## [0.2.0] — 2026-05-23

Cross-platform release. The repo now ships separate variants for Linux, macOS, and Windows.

### Added
- **macOS variant** (`macos/`): bash + launchd + `osascript` notifications. Uses `vm_stat` to derive an available-memory metric (free + inactive + speculative pages). Marked *untested by author* in README.
- **Windows variant** (`windows/`): PowerShell + Scheduled Task + `NotifyIcon` balloon tips (auto-promoted to toast notifications on Windows 10+). Uses the `\Memory\Available MBytes` performance counter. Marked *untested by author* in README.
- Top-level `install.sh` dispatcher that detects `uname` and forwards to the platform-specific installer; falls back to cloning the repo when run via `curl | bash`.
- README now documents all three platforms with a "Status" table noting test coverage.

### Changed
- **BREAKING**: Linux files moved from repo root into `linux/` subdir. `linux/install.sh`, `linux/uninstall.sh`, etc. The top-level `install.sh` is now a dispatcher.
- Shell config example consolidated to `config.example.sh` at repo root (shared by Linux and macOS).

### Fix (carried over from 0.1.0 post-release)
- `top_consumers` rewritten as a single awk to avoid `set -o pipefail` + `head -5` SIGPIPE.
- `notify-send --wait` wrapped in `timeout 45s` so GNOME's notification daemon can't block the script forever.
- Heredoc `\033` escape codes replaced with `printf` calls in installers.

## [0.1.0] — 2026-05-23

Initial release.

### Added
- `bin/ram-rescue` — periodic low-memory check; reads `/proc/meminfo`, fires `notify-send` when `MemAvailable` falls below threshold.
- `bin/ram-rescue-ctl` — user CLI with `status`, `test`, `open`, `snooze`, `unsnooze`, `logs`, `uninstall`, `version` commands.
- `install.sh` — one-shot installer (also serves as `curl | bash` target).
- `uninstall.sh` — standalone uninstaller (mirrors `ram-rescue uninstall`).
- Systemd-user timer (`OnUnitActiveSec=60s`) and oneshot service.
- Multi-desktop detection: GNOME, KDE Plasma, XFCE, MATE, Cinnamon, plus terminal+htop fallback.
- Notification action buttons: "Open Monitor" and "Snooze 30m".
- Snooze persistence in `$XDG_STATE_HOME/ram-rescue/quiet-until`.
- Journald logging via `logger -t ram-rescue`.
- GitHub Actions CI: `shellcheck` + `shfmt --diff`.
