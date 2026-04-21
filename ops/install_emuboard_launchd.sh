#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLIST_NAME="com.brnpal.emuboard.plist"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME"
LOG_DIR="$REPO_ROOT/logs"
NODE_PATH="$(command -v node)"
APP_DIR="$HOME/Applications"
APP_NAME="EmuBoard Launcher.app"
APP_PATH="$APP_DIR/$APP_NAME"
APPLESCRIPT_PATH="$REPO_ROOT/logs/emuboard_launcher.applescript"
ICON_SOURCE="$REPO_ROOT/assets/favicon.png"
LSREGISTER_PATH="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
PLIST_BUDDY="/usr/libexec/PlistBuddy"
CODESIGN_PATH="$(command -v codesign || true)"

if [[ -z "$NODE_PATH" ]]; then
  echo "Could not find node on PATH."
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$LOG_DIR"
mkdir -p "$APP_DIR"

build_launcher_icon() {
  if [[ ! -f "$ICON_SOURCE" ]]; then
    return 0
  fi

  local iconset_root
  local iconset_dir
  iconset_root="$(mktemp -d /tmp/emuboard.icon.XXXXXX)"
  iconset_dir="$iconset_root/EmuBoard.iconset"
  mkdir -p "$iconset_dir"

  sips -z 16 16 "$ICON_SOURCE" --out "$iconset_dir/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_SOURCE" --out "$iconset_dir/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_SOURCE" --out "$iconset_dir/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_SOURCE" --out "$iconset_dir/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_SOURCE" --out "$iconset_dir/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_SOURCE" --out "$iconset_dir/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_SOURCE" --out "$iconset_dir/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_SOURCE" --out "$iconset_dir/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_SOURCE" --out "$iconset_dir/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_SOURCE" --out "$iconset_dir/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$iconset_dir" -o "$APP_PATH/Contents/Resources/applet.icns"
  rm -rf "$iconset_root"
}

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

cat > "$APPLESCRIPT_PATH" <<APPLESCRIPT
on run argv
    do shell script quoted form of "$REPO_ROOT/ops/open_emuboard.sh" & " >/tmp/emuboard-launcher.log 2>&1 &"
end run

on open location this_URL
    do shell script quoted form of "$REPO_ROOT/ops/open_emuboard.sh" & " " & quoted form of this_URL & " >/tmp/emuboard-launcher.log 2>&1 &"
end open location
APPLESCRIPT

rm -rf "$APP_PATH"
osacompile -o "$APP_PATH" "$APPLESCRIPT_PATH"
build_launcher_icon

"$PLIST_BUDDY" -c "Add :CFBundleURLTypes array" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
"$PLIST_BUDDY" -c "Delete :CFBundleURLTypes" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
"$PLIST_BUDDY" -c "Add :CFBundleURLTypes array" "$APP_PATH/Contents/Info.plist"
"$PLIST_BUDDY" -c "Add :CFBundleURLTypes:0 dict" "$APP_PATH/Contents/Info.plist"
"$PLIST_BUDDY" -c "Add :CFBundleURLTypes:0:CFBundleURLName string EmuBoard" "$APP_PATH/Contents/Info.plist"
"$PLIST_BUDDY" -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$APP_PATH/Contents/Info.plist"
"$PLIST_BUDDY" -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string emuboard" "$APP_PATH/Contents/Info.plist"
"$PLIST_BUDDY" -c "Add :LSUIElement bool true" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true

if [[ -n "$CODESIGN_PATH" ]]; then
  "$CODESIGN_PATH" --force --sign - "$APP_PATH" >/dev/null 2>&1 || true
fi

if [[ -x "$LSREGISTER_PATH" ]]; then
  "$LSREGISTER_PATH" -f "$APP_PATH" >/dev/null 2>&1 || true
fi

echo "Installed LaunchAgent at $PLIST_PATH"
echo "Installed bookmark launcher at $APP_PATH"
echo "Save a browser bookmark to emuboard://open"
echo "The launcher will start EmuBoard and then open http://127.0.0.1:8080/"
