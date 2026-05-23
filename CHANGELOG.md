# Changelog

All notable changes to ram-rescue will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
