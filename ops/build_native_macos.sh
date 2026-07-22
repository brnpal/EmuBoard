#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$REPO_ROOT/EmuBoardMac/EmuBoardMac.xcodeproj"
BUILD_ROOT="$REPO_ROOT/EmuBoardMac/build"
DIST_ROOT="$REPO_ROOT/dist"
APP_SOURCE="$BUILD_ROOT/Build/Products/Release/EmuBoard.app"
APP_DESTINATION="$DIST_ROOT/EmuBoard.app"

xcodebuild \
  -project "$PROJECT" \
  -scheme EmuBoard \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$BUILD_ROOT" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

mkdir -p "$DIST_ROOT"
if [[ -d "$APP_DESTINATION" ]]; then
  /usr/bin/xattr -w com.brnpal.EmuBoard.previous-build "$(date -u +%FT%TZ)" "$APP_DESTINATION" 2>/dev/null || true
  /bin/rm -rf "$APP_DESTINATION"
fi
/usr/bin/ditto "$APP_SOURCE" "$APP_DESTINATION"
/usr/bin/codesign --force --deep --sign - "$APP_DESTINATION"

echo "Built $APP_DESTINATION"
