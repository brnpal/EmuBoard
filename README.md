# EmuBoard

EmuBoard is a local browser frontend for launching games from your OpenEmu and Dolphin libraries.

## Bookmark flow

The cleanest setup is:

1. Install the background LaunchAgent once with `npm run install:launchd`
2. Save a browser bookmark to `http://127.0.0.1:8080/`
3. Click the bookmark whenever you want to open EmuBoard
4. Click a game card in EmuBoard to launch it

## Local commands

- `npm start` runs the server in the foreground
- `npm run install:launchd` installs a macOS LaunchAgent so the app stays available for bookmarks
- `npm run uninstall:launchd` removes that LaunchAgent
