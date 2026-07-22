# EmuBoard

EmuBoard is a native game-library launcher that unifies OpenEmu, Dolphin, Ship of Harkinian, 2 Ship 2 Harkinian, and Dusklight behind one polished interface.

The native macOS app is the current product. It does not run a web server, open a browser, or require Node. The original browser implementation remains in the repository as a migration reference.

## Native macOS app

Requirements:

- macOS 13 Ventura or newer
- Xcode 15 or newer to build from source
- One or more supported emulator/native-port apps installed

Build a signed local app bundle:

```sh
./ops/build_native_macos.sh
```

The result is `dist/EmuBoard.app`. To also install it into `/Applications`:

```sh
./ops/install_native_macos.sh
```

You can develop it by opening [EmuBoardMac/EmuBoardMac.xcodeproj](EmuBoardMac/EmuBoardMac.xcodeproj) in Xcode and running the EmuBoard scheme.

### What it discovers

- OpenEmu ROMs and artwork, read directly from the local OpenEmu library
- Dolphin GameCube/Wii images (`iso`, `gcm`, `ciso`, `wbfs`, `rvz`, `wia`, `dol`, and `elf`)
- Ship of Harkinian, 2 Ship 2 Harkinian, and Dusklight when installed in `/Applications`
- The existing Twilight Princess artwork and Dusklight launch path

Default ROM locations match the original EmuBoard setup. Both can be changed in the native Settings window.

### Native architecture

- SwiftUI/AppKit interface optimized for macOS
- Direct SQLite artwork metadata access instead of shelling out to `sqlite3`
- Native `NSWorkspace` launching with Dolphin batch mode
- Local preferences for recents, favorites, and library paths
- Asynchronous scanning and lazy UI collections for large libraries

EmuBoard launches the optimized emulator or native port directly into a selected game. The renderer's gameplay window remains owned by that engine; its library/dashboard UI is bypassed or suppressed where the engine permits it.

## Windows and Linux direction

The library, game, system, and launcher concepts are deliberately separated from the macOS views. Windows and Linux should receive optimized platform-native shells and launcher adapters rather than making the Mac app carry a browser runtime. Those targets are not yet included in this milestone.

## Legacy browser app

- `npm start` runs the old local server in the foreground
- `npm run install:launchd` installs its macOS LaunchAgent and bookmark launcher
- `npm run uninstall:launchd` removes that LaunchAgent
