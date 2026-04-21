#!/bin/zsh

set -euo pipefail

PLIST_PATH="$HOME/Library/LaunchAgents/com.brnpal.emuboard.plist"
APP_PATH="$HOME/Applications/EmuBoard Launcher.app"

if [[ -f "$PLIST_PATH" ]]; then
  launchctl bootout "gui/$(id -u)" "$PLIST_PATH" >/dev/null 2>&1 || true
  rm -f "$PLIST_PATH"
  echo "Removed $PLIST_PATH"
else
  echo "No EmuBoard LaunchAgent was installed."
fi

if [[ -d "$APP_PATH" ]]; then
  rm -rf "$APP_PATH"
  echo "Removed $APP_PATH"
fi
