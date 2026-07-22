#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILT_APP="$REPO_ROOT/dist/EmuBoard.app"
INSTALLED_APP="/Applications/EmuBoard.app"

if [[ ! -d "$BUILT_APP" ]]; then
  "$SCRIPT_DIR/build_native_macos.sh"
fi

if [[ -d "$INSTALLED_APP" ]]; then
  TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
  /usr/bin/ditto "$INSTALLED_APP" "$REPO_ROOT/dist/EmuBoard-$TIMESTAMP.backup.app"
fi

/usr/bin/ditto "$BUILT_APP" "$INSTALLED_APP"
/usr/bin/codesign --verify --deep --strict "$INSTALLED_APP"

echo "Installed $INSTALLED_APP"
echo "Open it from Applications, Spotlight, or Launchpad."
