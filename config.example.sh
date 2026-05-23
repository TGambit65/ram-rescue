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
