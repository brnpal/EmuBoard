# EmuBoard

EmuBoard is a local browser frontend for launching games from your OpenEmu and Dolphin libraries.

## Bookmark flow

The cleanest setup is:

1. Install the background LaunchAgent once with `npm run install:launchd`
2. Save a browser bookmark to `emuboard://open`
3. Click the bookmark whenever you want to open EmuBoard
4. Click a game card in EmuBoard to launch it

The `emuboard://open` bookmark uses a small local launcher app that wakes the LaunchAgent if needed, waits for the health check on port `8080`, and then opens the local UI in your browser. If you ever want the raw local address, it is still `http://127.0.0.1:8080/`.

## Local commands

- `npm start` runs the server in the foreground
- `npm run install:launchd` installs the macOS LaunchAgent plus the `emuboard://` bookmark launcher
- `npm run open:bookmark` starts EmuBoard without opening a browser, which is handy for a quick health-check
- `npm run uninstall:launchd` removes that LaunchAgent
