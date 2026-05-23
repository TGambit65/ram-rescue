#!/usr/bin/env bash
# ram-rescue classifier library — sourced by ram-rescue and ram-rescue-overlay.
# Provides: classify_app, count_chrome_tabs, severity_emoji, build_app_table.
# This file is sourced, NOT executed directly.

# ---------------------------------------------------------------- app classifier
# Maps a process `comm` to "AppName<TAB>Emoji<TAB>Description<TAB>Category".
# First match wins. Unknown processes fall through to "$comm + package emoji".
classify_app() {
  case "$1" in
    chrome | chromium | google-chrome* | chromium-browser)
      printf '%s\t%s\t%s\t%s\n' "Chrome" "🌐" "Web browser" "browser" ;;
    firefox*)
      printf '%s\t%s\t%s\t%s\n' "Firefox" "🦊" "Web browser" "browser" ;;
    brave | brave-browser)
      printf '%s\t%s\t%s\t%s\n' "Brave" "🦁" "Web browser" "browser" ;;
    opera | Opera)
      printf '%s\t%s\t%s\t%s\n' "Opera" "🔵" "Web browser" "browser" ;;
    Code | code | code-insiders | codium | VSCodium)
      printf '%s\t%s\t%s\t%s\n' "VS Code" "📝" "Code editor" "editor" ;;
    cursor | Cursor)
      printf '%s\t%s\t%s\t%s\n' "Cursor" "✨" "AI code editor" "editor" ;;
    claude)
      printf '%s\t%s\t%s\t%s\n' "Claude Code" "🤖" "Anthropic AI agent" "ai" ;;
    aider)
      printf '%s\t%s\t%s\t%s\n' "Aider" "🤖" "AI pair programmer" "ai" ;;
    openclaw | clawd)
      printf '%s\t%s\t%s\t%s\n' "OpenClaw" "🦞" "AI gateway" "ai" ;;
    slack)
      printf '%s\t%s\t%s\t%s\n' "Slack" "💬" "Team chat" "chat" ;;
    discord | Discord)
      printf '%s\t%s\t%s\t%s\n' "Discord" "🎮" "Chat app" "chat" ;;
    telegram-desktop | Telegram)
      printf '%s\t%s\t%s\t%s\n' "Telegram" "✈️" "Chat app" "chat" ;;
    spotify | Spotify)
      printf '%s\t%s\t%s\t%s\n' "Spotify" "🎵" "Music streaming" "media" ;;
    zoom | Zoom | zoom.us)
      printf '%s\t%s\t%s\t%s\n' "Zoom" "🎥" "Video calls" "media" ;;
    obs | OBS | obs-studio)
      printf '%s\t%s\t%s\t%s\n' "OBS Studio" "📹" "Streaming/recording" "media" ;;
    vlc | VLC)
      printf '%s\t%s\t%s\t%s\n' "VLC" "🎬" "Media player" "media" ;;
    node | nodejs)
      printf '%s\t%s\t%s\t%s\n' "Node.js" "⚙️" "JavaScript runtime" "runtime" ;;
    npm | "npm exec"* | "npm run"*)
      printf '%s\t%s\t%s\t%s\n' "npm" "📦" "npm-managed Node process" "runtime" ;;
    "next-server"*)
      printf '%s\t%s\t%s\t%s\n' "Next.js dev" "▲" "Next.js development server" "server" ;;
    "vite"* | esbuild)
      printf '%s\t%s\t%s\t%s\n' "Vite/esbuild" "⚡" "Frontend dev tooling" "server" ;;
    webpack*)
      printf '%s\t%s\t%s\t%s\n' "webpack" "📦" "Bundler" "runtime" ;;
    python | python3 | python3.* | python2 | python2.*)
      printf '%s\t%s\t%s\t%s\n' "Python" "🐍" "Python interpreter" "runtime" ;;
    uvicorn)
      printf '%s\t%s\t%s\t%s\n' "uvicorn" "📡" "Python ASGI web server" "server" ;;
    gunicorn)
      printf '%s\t%s\t%s\t%s\n' "gunicorn" "📡" "Python WSGI web server" "server" ;;
    java | javaw)
      printf '%s\t%s\t%s\t%s\n' "Java" "☕" "JVM application" "runtime" ;;
    ruby)
      printf '%s\t%s\t%s\t%s\n' "Ruby" "💎" "Ruby interpreter" "runtime" ;;
    rust | cargo | rustc)
      printf '%s\t%s\t%s\t%s\n' "Rust" "🦀" "Rust toolchain" "runtime" ;;
    docker | dockerd | containerd | containerd-shim*)
      printf '%s\t%s\t%s\t%s\n' "Docker" "🐳" "Container runtime" "system" ;;
    postgres | postgresql | postmaster)
      printf '%s\t%s\t%s\t%s\n' "PostgreSQL" "🐘" "Database" "server" ;;
    mysqld | mariadbd)
      printf '%s\t%s\t%s\t%s\n' "MySQL" "🐬" "Database" "server" ;;
    redis-server)
      printf '%s\t%s\t%s\t%s\n' "Redis" "📕" "In-memory database" "server" ;;
    mongod)
      printf '%s\t%s\t%s\t%s\n' "MongoDB" "🍃" "Document database" "server" ;;
    nginx)
      printf '%s\t%s\t%s\t%s\n' "nginx" "🚀" "Web server" "server" ;;
    AionUi | aion-ui)
      printf '%s\t%s\t%s\t%s\n' "AionUi" "🪟" "Desktop app" "app" ;;
    gnome-shell | gnome-session* | gjs | nautilus | gsd-* | gnome-software | tracker3 | tracker-extract* | evolution-* | goa-daemon)
      printf '%s\t%s\t%s\t%s\n' "GNOME" "🖥️" "Desktop env (keep alive)" "system" ;;
    plasmashell | kded5 | kwin* | krunner | plasma-discover | baloo*)
      printf '%s\t%s\t%s\t%s\n' "KDE Plasma" "🖥️" "Desktop env (keep alive)" "system" ;;
    Xorg | Xwayland | xwayland)
      printf '%s\t%s\t%s\t%s\n' "X server" "🖥️" "Display server (keep alive)" "system" ;;
    systemd | systemd-* | init | dbus-* | polkitd | NetworkManager | wpa_supplicant | ModemManager | snapd | upowerd | gdm* | login*)
      printf '%s\t%s\t%s\t%s\n' "systemd & system" "⚙️" "System services (keep alive)" "system" ;;
    pulseaudio | pipewire | pipewire-* | wireplumber)
      printf '%s\t%s\t%s\t%s\n' "Audio system" "🔊" "Audio daemon" "system" ;;
    bash | zsh | sh | fish | dash)
      printf '%s\t%s\t%s\t%s\n' "Shell sessions" "🐚" "Login shells & subshells" "shell" ;;
    gnome-terminal* | konsole | xterm | kitty | alacritty | wezterm)
      printf '%s\t%s\t%s\t%s\n' "Terminal" "🖥️" "Terminal emulator" "app" ;;
    *)
      printf '%s\t%s\t%s\t%s\n' "$1" "📦" "Process" "other" ;;
  esac
}

# Approximate Chrome tab count: renderer processes excluding extension renderers.
count_chrome_tabs() {
  local count
  count=$(pgrep -af 'chrome|chromium' 2>/dev/null |
    awk '/type=renderer/ && !/extension-process/' |
    wc -l) || count=0
  echo "${count:-0}"
}

# Severity emoji based on available-memory percentage.
severity_emoji() {
  local pct=$1
  if ((pct < 5)); then
    echo "🔴"
  elif ((pct < 10)); then
    echo "🟠"
  else
    echo "🟡"
  fi
}

# Populates 4 global associative arrays + a sorted-by-RSS list.
# Callers must declare:
#   declare -A APP_RSS APP_COUNT APP_EMOJI APP_DESC APP_CAT
#   APP_SORTED=""
build_app_table() {
  local rss comm info name emoji desc cat cur

  set +u
  while read -r rss comm; do
    [[ -z "$comm" ]] && continue
    ((rss == 0)) && continue
    info=$(classify_app "$comm")
    IFS=$'\t' read -r name emoji desc cat <<<"$info"
    cur=${APP_RSS[$name]:-0}
    APP_RSS[$name]=$((cur + rss))
    cur=${APP_COUNT[$name]:-0}
    APP_COUNT[$name]=$((cur + 1))
    APP_EMOJI[$name]="$emoji"
    APP_DESC[$name]="$desc"
    APP_CAT[$name]="$cat"
  done < <(ps -eo rss,comm --no-headers)
  set -u

  APP_SORTED=$(for name in "${!APP_RSS[@]}"; do
    printf '%d\t%s\n' "${APP_RSS[$name]}" "$name"
  done | sort -rn)
}

# Format a size in KB to "X MB" or "X.Y GB" string.
format_size() {
  local kb=$1
  local mb=$((kb / 1024))
  if ((mb >= 1024)); then
    awk -v m="$mb" 'BEGIN{printf "%.1f GB", m/1024}'
  else
    echo "${mb} MB"
  fi
}
