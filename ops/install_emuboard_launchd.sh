#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLIST_NAME="com.brnpal.emuboard.plist"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME"
LOG_DIR="$REPO_ROOT/logs"
NODE_PATH="$(command -v node)"

if [[ -z "$NODE_PATH" ]]; then
  echo "Could not find node on PATH."
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$LOG_DIR"

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.brnpal.emuboard</string>

    <key>ProgramArguments</key>
    <array>
      <string>$NODE_PATH</string>
      <string>$REPO_ROOT/server.js</string>
    </array>

    <key>EnvironmentVariables</key>
    <dict>
      <key>EMUBOARD_HOST</key>
      <string>127.0.0.1</string>
      <key>EMUBOARD_PORT</key>
      <string>8080</string>
    </dict>

    <key>WorkingDirectory</key>
    <string>$REPO_ROOT</string>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>$LOG_DIR/emuboard.stdout.log</string>

    <key>StandardErrorPath</key>
    <string>$LOG_DIR/emuboard.stderr.log</string>
  </dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)" "$PLIST_PATH" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
launchctl kickstart -k "gui/$(id -u)/com.brnpal.emuboard"

echo "Installed LaunchAgent at $PLIST_PATH"
echo "EmuBoard will stay available at http://127.0.0.1:8080/"
