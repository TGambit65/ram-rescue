# ram-rescue config — shell-sourced KEY=VALUE
# Location: ~/.config/ram-rescue/config (or $XDG_CONFIG_HOME/ram-rescue/config)

# Alert when MemAvailable falls below this percentage of MemTotal.
THRESHOLD_PCT=15

# After an alert (without explicit snooze), don't re-alert for this many seconds.
COOLDOWN_SEC=600

# Duration of an explicit "Snooze" click, in seconds.
SNOOZE_DURATION=1800

# Override desktop detection. Leave blank to auto-detect.
# Examples:
#   MONITOR_CMD="gnome-system-monitor"
#   MONITOR_CMD="plasma-systemmonitor"
#   MONITOR_CMD="xfce4-taskmanager"
#   MONITOR_CMD="gnome-terminal -- htop"
MONITOR_CMD=""

# PSI (memory pressure) trigger — kernel >= 4.20 required.
# Alert when /proc/pressure/memory `some avg10` exceeds this percentage.
# Catches swap-thrashing situations the MemAvailable threshold misses.
# Set to 0 to disable. Typical values: 5.0 (sensitive), 10.0 (default), 20.0 (only severe).
PSI_AVG10_THRESHOLD=10.0

# Watch kernel OOM-killer events (journalctl -k) and surface them as a
# post-mortem notification. Tells you what the OS killed while you were AFK.
# 1 = on (default), 0 = off.
OOM_WATCH=1
