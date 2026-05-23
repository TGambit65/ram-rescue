# ram-rescue

**A cross-platform low-RAM alerter, built for the era when you run Claude Code, Cursor, and 50 browser tabs at once.**

Linux GNOME doesn't warn before RAM exhaustion freezes your machine. macOS and Windows do warn — but only at *critical* levels, far too late for an agentic workflow. ram-rescue fires a *configurable* early warning when available memory drops below your threshold (default: 15%), lists the top 5 memory consumers, and gives you one-click access to the system monitor so you can pick what to kill.

**Zero daemon, zero idle cost.** On Linux, a systemd timer wakes a bash script every 60 seconds. On macOS, a launchd agent. On Windows, a Scheduled Task. Each script reads memory, decides whether to alert, and exits. No background process, no Electron, no GUI framework — those would defeat the point of a tool that manages your RAM.

### What the alert looks like

```
🟡 Low memory · 12% available
3,900 MB free of 32,009 MB · Top apps:

🌐 Chrome · 6.6 GB · ~45 tabs
🐍 Python · 1.5 GB · Python interpreter
🤖 Claude Code · 1.1 GB · Anthropic AI agent
🖥️ GNOME · 1006 MB · Desktop env (keep alive)
📡 uvicorn · 908 MB · Python ASGI web server
                                       [Open Monitor] [Snooze 30m]
```

Processes are **grouped by app** so you see one row per program (not 50 rows of chrome subprocesses). Each app gets a one-line summary so you know what it is before you kill it. Severity emoji in the title (🟡 / 🟠 / 🔴) tells you at a glance how bad it is. Browsers show an approximate **tab count** so you know whether to close tabs or quit the whole browser.

Install in one line. Uninstall in one line.

---

## Status

| Platform | Status | Mechanism |
|---|---|---|
| **Linux** (GNOME, KDE, XFCE, MATE, Cinnamon) | ✅ Tested by author (Ubuntu 24 + GNOME 46) | bash + systemd-user + `notify-send` |
| **macOS** | ⚠️ Untested by author — please file issues | bash + launchd + `osascript` notifications |
| **Windows** (10 / 11) | ⚠️ Untested by author — please file issues | PowerShell + Scheduled Task + Toast notifications |

If you run macOS or Windows and want to dogfood, please open an issue with what you observe — it's the fastest path to "Tested" status.

## Why this exists

If you use AI coding agents heavily — Claude Code, Cursor, Aider, Continue, OpenClaw — you've probably hit a freeze where the system stops responding because every browser tab, every language server, and every running agent is fighting for the last gigabyte of RAM.

- **Linux GNOME** has *no* low-memory warning. The machine just starts swapping until it's unusable.
- **macOS** shows *"Your system has run out of application memory"* — but only when you're already swapping hard, not when you could still rescue the situation.
- **Windows** shows *"Your computer is low on memory"* — same problem: it's a critical alert, not an early warning.

ram-rescue is the missing *early* warning: a small native script per platform that watches available memory and pops a notification with a top-5 consumer list while you can still do something about it.

## Quick install

### Linux

```bash
curl -fsSL https://raw.githubusercontent.com/TGambit65/ram-rescue/main/install.sh | bash
```

The dispatcher auto-detects Linux and runs `linux/install.sh`.

### macOS

```bash
curl -fsSL https://raw.githubusercontent.com/TGambit65/ram-rescue/main/install.sh | bash
```

Same dispatcher; auto-detects Darwin and runs `macos/install.sh`. First-time notification permission may be required (System Settings → Notifications).

### Windows

PowerShell required:

```powershell
iwr -useb https://raw.githubusercontent.com/TGambit65/ram-rescue/main/windows/install.ps1 | iex
```

Or clone and run:

```powershell
git clone https://github.com/TGambit65/ram-rescue
cd ram-rescue
powershell -ExecutionPolicy Bypass -File windows\install.ps1
```

### Verify

After install, on any platform:

```
ram-rescue status     # current RAM + agent/task/timer state
ram-rescue test       # force a test alert
```

## Configure

Config is per-platform but uses the same variable names:

- **Linux / macOS**: `~/.config/ram-rescue/config` (shell-sourced KEY=VALUE)
- **Windows**: `%LOCALAPPDATA%\ram-rescue\config.ps1` (PowerShell, dot-sourced)

```
THRESHOLD_PCT=15        # alert when MemAvailable < this percent
COOLDOWN_SEC=600        # don't re-alert for this many seconds after an alert
SNOOZE_DURATION=1800    # duration of an explicit "Snooze" click
```

After editing, no restart needed — the next scheduled run picks up the new values.

## How it works

```
                        ┌─────────────────────┐
                        │  Periodic trigger   │
                        │  Linux: systemd     │
                        │  macOS: launchd     │
                        │  Windows: schtasks  │
                        └──────────┬──────────┘
                                   │  every 60s
                                   ▼
        ┌────────────────────────────────────────────────────┐
        │  1. Read available memory (platform-specific)      │
        │  2. If above threshold → exit silently             │
        │  3. If in snooze window → exit silently            │
        │  4. Otherwise: collect top-5 memory consumers      │
        │  5. Fire desktop notification                      │
        │  6. Log to system log (journald / log / EventLog)  │
        └────────────────────────────────────────────────────┘
```

**Idle cost when memory is fine: ~0 MB.** No process stays resident — the script runs in ~50ms and exits.

### Platform-specific memory metrics

| Platform | Metric used |
|---|---|
| Linux | `/proc/meminfo` → `MemAvailable` |
| macOS | `vm_stat` → `free + inactive + speculative` pages |
| Windows | `\Memory\Available MBytes` performance counter |

Compressed memory (macOS) and standby memory (Windows) are treated as available, matching how the OS itself reasons about pressure.

## Linux multi-desktop support

Auto-detects via `$XDG_CURRENT_DESKTOP`:

| Desktop | System monitor |
|---|---|
| GNOME / Unity / Cinnamon | `gnome-system-monitor` |
| KDE Plasma | `plasma-systemmonitor` (fallback `ksysguard`) |
| XFCE | `xfce4-taskmanager` |
| MATE | `mate-system-monitor` |
| Unknown / minimal WM | `gnome-terminal -- htop` or `xterm -e htop` |

Override with `MONITOR_CMD="..."` in your config.

**XFCE caveat**: `xfce4-notifyd` doesn't render `--action` buttons. The alert body includes a fallback hint telling you to run `ram-rescue open`. Or switch to `dunst` for full action support.

**Action buttons (Linux only in v0.2.0)**: GNOME and KDE notifications include `Open Monitor` and `Snooze 30m` buttons. macOS and Windows fall back to body text instructing the user to run `ram-rescue open`. A v0.3.0 follow-up will add native action buttons on macOS (via Cocoa) and Windows (via BurntToast / native toast XML).

## CLI reference (all platforms)

```
ram-rescue status              Show current memory state and agent status
ram-rescue apps                Show top apps grouped by name (no notification)
ram-rescue overlay             Open the on-demand kill picker (Linux v0.4.0+)
ram-rescue test                Force a low-memory alert
ram-rescue open                Launch the system monitor / Activity Monitor / Task Manager
ram-rescue snooze [SECONDS]    Suppress alerts for N seconds (default: 1800)
ram-rescue unsnooze            Clear any active snooze
ram-rescue logs [N]            Show last N log lines
ram-rescue version             Print version
ram-rescue uninstall           Remove everything
ram-rescue help                This message
```

`ram-rescue apps` prints the same grouped view that the notification shows, but to your terminal — great for ad-hoc inspection or scripting.

## Hotkey-launched kill picker (Linux, v0.4.0+)

The `overlay` subcommand opens a zenity checklist of all running apps, lets you tick the ones to close, confirms, then sends SIGTERM to each. Closes itself when done.

**Bind a hotkey at install time (GNOME):**

```bash
./linux/install.sh --bind-hotkey            # binds Super+R (default)
./linux/install.sh --bind-hotkey=Ctrl+Alt+R # any combo you want
```

For `curl | bash` users, the flag works through the dispatcher too:

```bash
curl -fsSL https://raw.githubusercontent.com/TGambit65/ram-rescue/main/install.sh | bash -s -- --bind-hotkey
```

Accepted accelerator formats: `Super+R`, `Ctrl+Alt+R`, `Super+Escape`, or raw GTK form `<Super>r`. Other DEs (KDE / XFCE / MATE) print a warning and skip — bind manually via the DE's keyboard settings.

**Bind manually (any DE):**

1. Settings → Keyboard → View and Customize Shortcuts → Custom Shortcuts → `+`
2. Name: `ram-rescue overlay`
3. Command: `/home/YOUR_USER/.local/bin/ram-rescue overlay` (full path — DE shortcut runners often don't inherit `PATH`)
4. Shortcut: pick anything (`Super+R` recommended)

Now `Super+R` (or whatever you chose) anywhere on the desktop opens the picker. Uninstall removes the binding automatically.

### RAM cost — honest numbers

The overlay is **0 MB resident** (nothing runs between invocations) but **~200 MB while visible** because zenity 4.x on Ubuntu 24 pulls in GTK4 + GSK + Cairo + Pango + ~100 shared libraries. That's roughly the same as `gnome-system-monitor` itself (~215 MB visible), so the kill-picker isn't more expensive than what "Open Monitor" already launches.

If you want a lighter alternative, two options exist:
- **Python + Tkinter** rewrite: ~20 MB visible. Tracked for v0.4.1.
- **TUI** (whiptail/dialog inside a terminal): ~5 MB + ~50 MB for the terminal. Lighter overall but loses the "popup over any window" feel.

System-category processes (GNOME shell, X server, systemd, audio daemons, shells) are filtered out of the picker since killing them takes down your session.

## Troubleshooting

**Linux: no notification fires when I run `ram-rescue test`.**
Check that `notify-send` works at all: `notify-send "test"`. If nothing appears, your notification daemon isn't running. On GNOME, that's `gnome-shell`. On KDE, `plasmashell`. On lightweight WMs, install `dunst`.

**Linux: timer is active but no alerts during real low-memory.**
Check journald: `ram-rescue logs 50` and `journalctl --user -u ram-rescue.timer --since today`.

**macOS: notification permission denied.**
System Settings → Notifications → Script Editor → Allow notifications. (`osascript display notification` runs under Script Editor's identity.)

**macOS: `launchctl load` says "already loaded".**
Run `ram-rescue uninstall && ./macos/install.sh` to reset.

**Windows: notifications don't appear.**
Check Focus Assist (Settings → System → Focus Assist) — it may be set to suppress all notifications. Also check Notifications & Actions → make sure notifications from PowerShell are allowed.

**Windows: "execution policy" error.**
The installer uses `-ExecutionPolicy Bypass` for the install step, but ongoing runs use the user's policy. Set CurrentUser policy: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`.

## Uninstall

```bash
ram-rescue uninstall
```

Removes the timer / launchd agent / scheduled task, scripts, and CLI wrapper. Config and state directories are preserved — delete manually for a clean wipe.

## Contributing

Issues and PRs welcome. Linux scripts are covered by CI (`shellcheck` + `shfmt --diff`). macOS bash scripts are linted by the same CI workflow. PowerShell scripts are linted in a separate workflow (planned for v0.3.0).

**Especially welcome**: macOS and Windows dogfooding. The author runs Linux, so those variants are best-effort and need real-world testing.

## License

MIT — see [LICENSE](LICENSE).
