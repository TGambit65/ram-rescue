# ram-rescue

**A low-RAM alerter for Linux desktops, built for the era when you run Claude Code, Cursor, and 50 browser tabs simultaneously.**

macOS warns you. Windows warns you. GNOME doesn't — it just starts swapping until your machine becomes unusable. `ram-rescue` fires a desktop notification the moment available memory drops below your threshold, lists the top 5 memory consumers in the alert, and one click opens the system monitor so you can pick what to kill.

**Zero daemon, zero idle cost.** A systemd timer wakes a bash script every 60 seconds, checks `/proc/meminfo`, and exits. No Electron, no Tauri, no GUI — those would defeat the point of a tool that manages your RAM.

Install in one line. Uninstall in one line. Works on GNOME, KDE Plasma, XFCE, MATE, Cinnamon.

---

## Why this exists

If you use AI coding agents heavily — Claude Code, Cursor, Aider, Continue, OpenClaw — you've probably hit a freeze where the system stops responding because every browser tab, every language server, and every running agent is fighting for the last gigabyte of RAM. On macOS and Windows, the OS would have warned you minutes ago. On Linux GNOME, there's no warning. It just stops working.

`ram-rescue` is the missing alert: a 150-line bash script and a systemd-user timer that watches `MemAvailable` and pops a notification with one-click access to the system monitor.

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/TGambit65/ram-rescue/main/install.sh | bash
```

That installs the timer, the alert script, and a `ram-rescue` CLI to `~/.local/bin/`. The timer activates immediately.

Verify with:

```bash
ram-rescue status     # current RAM + timer state
ram-rescue test       # force a test alert
```

## Configure

Config lives at `~/.config/ram-rescue/config`:

```bash
THRESHOLD_PCT=15        # alert when MemAvailable < this percent
COOLDOWN_SEC=600        # don't re-alert for this many seconds after an alert
SNOOZE_DURATION=1800    # duration of an explicit "Snooze" click
MONITOR_CMD=""          # override desktop detection (auto by default)
```

After editing, no restart needed — the next timer run picks up the new values.

## How it works

```
┌──────────────────────────────────────────────────────────────┐
│  ram-rescue.timer (systemd-user)                             │
│  Fires every 60s after first 90s boot delay                  │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│  ram-rescue (~150 lines of bash, runs ~50ms, exits)          │
│  1. Read /proc/meminfo → MemAvailable%                       │
│  2. If above threshold → exit silently                       │
│  3. If in snooze window → exit silently                      │
│  4. Otherwise: ps -eo comm,rss --sort=-rss | head -5         │
│  5. notify-send with action buttons:                         │
│       [Open Monitor]   [Snooze 30m]                          │
│  6. Handle click → launch system monitor or set snooze       │
│  7. logger -t ram-rescue → journald                          │
└──────────────────────────────────────────────────────────────┘
```

Idle cost when memory is fine: ~0 MB. The script doesn't stay resident.

## Multi-desktop support

Auto-detects via `$XDG_CURRENT_DESKTOP` and launches the right system monitor:

| Desktop | Monitor command |
|---|---|
| GNOME / Unity / Cinnamon | `gnome-system-monitor` |
| KDE Plasma | `plasma-systemmonitor` (fallback `ksysguard`) |
| XFCE | `xfce4-taskmanager` |
| MATE | `mate-system-monitor` |
| Unknown / minimal WM | `gnome-terminal -- htop` or `xterm -e htop` |

Override with `MONITOR_CMD="..."` in your config.

> **Note for XFCE users**: `xfce4-notifyd` doesn't render `--action` buttons. The alert body includes a fallback hint telling you to run `ram-rescue open`. Or switch to `dunst` for full action support.

## CLI reference

```
ram-rescue status              Show current memory state and timer status
ram-rescue test                Force a low-memory alert (uses MEMAVAILABLE_OVERRIDE)
ram-rescue open                Launch the system monitor immediately
ram-rescue snooze [SECONDS]    Suppress alerts for N seconds (default: 1800)
ram-rescue unsnooze            Clear any active snooze
ram-rescue logs [N]            Show last N log lines from journald (default: 20)
ram-rescue version             Print version
ram-rescue uninstall           Remove everything
ram-rescue help                This message
```

## Troubleshooting

**No notification fires when I run `ram-rescue test`.**
Check that `notify-send` works at all:
```bash
notify-send "test"
```
If nothing appears, your notification daemon isn't running. On GNOME, that's `gnome-shell`. On KDE, it's `plasmashell`. On lightweight WMs, install `dunst`.

**Timer is active but no alerts during real low-memory.**
Check journald:
```bash
ram-rescue logs 50
journalctl --user -u ram-rescue.timer --since today
```
The timer logs each invocation; the script only logs when it fires or errors.

**Action buttons don't work on XFCE.**
This is `xfce4-notifyd`. Either run `ram-rescue open` from the terminal, or replace XFCE's notifier with `dunst`.

**My desktop isn't detected.**
Set `MONITOR_CMD="..."` in `~/.config/ram-rescue/config` to whatever you want to launch.

## Uninstall

```bash
ram-rescue uninstall
```

Removes the timer, service, scripts, and the `ram-rescue` symlink in `~/.local/bin`. Config and state directories are preserved — delete manually if you want a clean wipe:

```bash
rm -rf ~/.config/ram-rescue ~/.local/state/ram-rescue
```

## Why not Windows or macOS?

Both have this built in. macOS pops *"Your system has run out of application memory"* with a Force Quit dialog. Windows pops *"Your computer is low on memory"* with Task Manager. They're not perfect, but they exist. Linux desktop is the gap, and that's the gap this tool fills.

If you want similar functionality on Windows or macOS anyway, the closest matches are [Process Lasso](https://bitsum.com/) (Windows) and [iStat Menus](https://bjango.com/mac/istatmenus/) (macOS).

## Contributing

Issues and PRs welcome. Run `./test/shellcheck.sh` before submitting.

CI runs `shellcheck` + `shfmt --diff` on every push.

## License

MIT — see [LICENSE](LICENSE).

## Acknowledgments

Inspired by the pattern of small systemd-user utilities that fill desktop gaps. Built because the author runs 50+ tabs and 3 AI agents at once and got tired of hard reboots.
