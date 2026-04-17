#!/bin/zsh

set -euo pipefail

PLIST_PATH="$HOME/Library/LaunchAgents/com.brnpal.emuboard.plist"

if [[ -f "$PLIST_PATH" ]]; then
  launchctl bootout "gui/$(id -u)" "$PLIST_PATH" >/dev/null 2>&1 || true
  rm -f "$PLIST_PATH"
  echo "Removed $PLIST_PATH"
else
  echo "No EmuBoard LaunchAgent was installed."
fi
