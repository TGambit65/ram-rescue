# Changelog

All notable changes to ram-rescue will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
