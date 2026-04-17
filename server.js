const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { execSync, execFile } = require('child_process');

const app = express();
const HOST = process.env.EMUBOARD_HOST || '127.0.0.1';
const PORT = Number(process.env.EMUBOARD_PORT || process.env.PORT || 8080);
const GAMES_DIR = '/Users/brendanallaway/Documents/openemu games';
const DOLPHIN_GAMES_DIR = '/Users/brendanallaway/Documents/Dolphin Games';
const ARTWORK_DIR = '/Users/brendanallaway/Library/Application Support/OpenEmu/Game Library/Artwork';
const DB_PATH = '/Users/brendanallaway/Library/Application Support/OpenEmu/Game Library/Library.storedata';
const NATIVE_GAMES = [
    {
        id: 'soh-oot',
        title: 'The Legend of Zelda: Ocarina of Time',
        path: '/Users/brendanallaway/Library/Application Support/com.shipofharkinian.soh/oot.o2r',
        emulator: 'soh',
        appPath: '/Applications/soh.app',
        thumbnail: 'ocarina-of-time.jpg'
    },
    {
        id: '2s2h-mm',
        title: "The Legend of Zelda: Majora's Mask",
        path: '/Users/brendanallaway/Library/Application Support/com.2ship2harkinian.2s2h/mm.o2r',
        emulator: '2s2h',
        appPath: '/Applications/2s2h.app',
        thumbnail: 'majoras-mask.jpg'
    }
];
const EMULATOR_APPS = {
    OpenEmu: {
        appName: 'OpenEmu',
        appPath: 'OpenEmu',
        autoQuitWhenWindowCloses: true
    },
    Dolphin: {
        appName: 'Dolphin',
        appPath: 'Dolphin',
        autoQuitWhenWindowCloses: false
    },
    soh: {
        appName: 'soh',
        appPath: '/Applications/soh.app',
        autoQuitWhenWindowCloses: true
    },
    '2s2h': {
        appName: '2s2h',
        appPath: '/Applications/2s2h.app',
        autoQuitWhenWindowCloses: true
    }
};
const shutdownWatchers = new Map();
const WATCHER_START_DELAY_MS = 4000;
const WATCHER_POLL_INTERVAL_MS = 1500;
const WATCHER_ZERO_WINDOW_THRESHOLD = 2;
const APP_QUIT_WAIT_TIMEOUT_MS = 8000;

app.use(cors());
app.use(express.json());

app.get('/api/health', (_req, res) => {
    res.json({
        ok: true,
        host: HOST,
        port: PORT
    });
});

// Recent games storage functions
const RECENT_GAMES_FILE = path.join(__dirname, 'recent_games.json');

function getRecentGames() {
    try {
        if (fs.existsSync(RECENT_GAMES_FILE)) {
            return JSON.parse(fs.readFileSync(RECENT_GAMES_FILE, 'utf-8'));
        }
    } catch (e) {
        console.error("Error reading recent games:", e);
    }
    return {};
}

function updateRecentGame(romPath) {
    const recentGames = getRecentGames();
    recentGames[romPath] = Date.now();
    fs.writeFileSync(RECENT_GAMES_FILE, JSON.stringify(recentGames, null, 2));
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

function escapeAppleScriptString(value) {
    return value.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
}

function runAppleScript(script) {
    return new Promise((resolve, reject) => {
        execFile('osascript', ['-e', script], (error, stdout, stderr) => {
            if (error) {
                error.stderr = stderr;
                return reject(error);
            }

            resolve(stdout.trim());
        });
    });
}

function openApp(appPath, args = []) {
    return new Promise((resolve, reject) => {
        execFile('open', ['-a', appPath, ...args], (error, stdout, stderr) => {
            if (error) {
                error.stderr = stderr;
                return reject(error);
            }

            resolve(stdout.trim());
        });
    });
}

function getEmulatorAppConfig(emulator) {
    return EMULATOR_APPS[emulator] || EMULATOR_APPS.OpenEmu;
}

function maybeMonitorEmulatorAutoQuit(emulator) {
    const { appName, autoQuitWhenWindowCloses } = getEmulatorAppConfig(emulator);
    if (autoQuitWhenWindowCloses) {
        monitorAppForAutoQuit(appName);
    }
}

function stopShutdownWatcher(appName) {
    const watcher = shutdownWatchers.get(appName);
    if (!watcher) {
        return;
    }

    if (watcher.startTimeout) {
        clearTimeout(watcher.startTimeout);
    }

    if (watcher.interval) {
        clearInterval(watcher.interval);
    }

    shutdownWatchers.delete(appName);
}

function stopOtherShutdownWatchers(activeAppName) {
    for (const appName of shutdownWatchers.keys()) {
        if (appName !== activeAppName) {
            stopShutdownWatcher(appName);
        }
    }
}

async function isAppRunning(appName) {
    const escapedAppName = escapeAppleScriptString(appName);
    const result = await runAppleScript(`
        if application "${escapedAppName}" is running then
            return "yes"
        end if
        return "no"
    `);

    return result === 'yes';
}

async function getWindowCount(appName) {
    const escapedAppName = escapeAppleScriptString(appName);
    const result = await runAppleScript(`
        tell application "System Events"
            if not (exists process "${escapedAppName}") then
                return "-1"
            end if

            tell process "${escapedAppName}"
                return (count of windows) as string
            end tell
        end tell
    `);

    return Number.parseInt(result, 10);
}

async function quitApp(appName) {
    const escapedAppName = escapeAppleScriptString(appName);

    await runAppleScript(`
        if application "${escapedAppName}" is running then
            tell application "${escapedAppName}" to quit
        end if
    `);

    const timeoutAt = Date.now() + APP_QUIT_WAIT_TIMEOUT_MS;
    while (Date.now() < timeoutAt) {
        if (!(await isAppRunning(appName))) {
            return true;
        }

        await sleep(500);
    }

    return false;
}

async function quitOtherEmulators(activeEmulator) {
    const activeAppName = getEmulatorAppConfig(activeEmulator).appName;
    const emulatorAppNames = [...new Set(Object.values(EMULATOR_APPS).map(config => config.appName))];

    stopOtherShutdownWatchers(activeAppName);

    for (const appName of emulatorAppNames) {
        if (appName === activeAppName) {
            continue;
        }

        try {
            if (await isAppRunning(appName)) {
                console.log(`Quitting ${appName} before launching ${activeAppName}`);
                await quitApp(appName);
            }
        } catch (error) {
            console.error(`Failed to quit ${appName}:`, error);
        }
    }
}

function monitorAppForAutoQuit(appName) {
    stopShutdownWatcher(appName);

    const watcher = {
        interval: null,
        pollInProgress: false,
        sawWindow: false,
        startTimeout: null,
        zeroWindowPolls: 0
    };

    const pollWindows = async () => {
        if (watcher.pollInProgress) {
            return;
        }

        watcher.pollInProgress = true;

        try {
            const windowCount = await getWindowCount(appName);
            if (windowCount === -1) {
                stopShutdownWatcher(appName);
                return;
            }

            if (windowCount > 0) {
                watcher.sawWindow = true;
                watcher.zeroWindowPolls = 0;
                return;
            }

            if (!watcher.sawWindow) {
                return;
            }

            watcher.zeroWindowPolls += 1;
            if (watcher.zeroWindowPolls < WATCHER_ZERO_WINDOW_THRESHOLD) {
                return;
            }

            console.log(`${appName} has no windows open. Quitting the app.`);
            stopShutdownWatcher(appName);
            await quitApp(appName);
        } catch (error) {
            stopShutdownWatcher(appName);
            console.error(`Auto-quit watcher failed for ${appName}:`, error);
        } finally {
            watcher.pollInProgress = false;
        }
    };

    watcher.startTimeout = setTimeout(() => {
        watcher.interval = setInterval(pollWindows, WATCHER_POLL_INTERVAL_MS);
        pollWindows();
    }, WATCHER_START_DELAY_MS);

    shutdownWatchers.set(appName, watcher);
}

function scheduleOpenEmuLibraryClose() {
    let attempts = 0;
    let hideInProgress = false;
    const hideInterval = setInterval(async () => {
        if (hideInProgress) {
            return;
        }

        attempts += 1;
        hideInProgress = true;

        try {
            const result = await runAppleScript(`
                tell application "System Events"
                    tell process "OpenEmu"
                        if exists window "OpenEmu" then
                            click button 1 of window "OpenEmu"
                            return "closed"
                        end if
                    end tell
                end tell
                return "not_found"
            `);

            if (result === 'closed' || attempts >= 5) {
                clearInterval(hideInterval);
            }
        } catch (error) {
            if (attempts >= 5) {
                clearInterval(hideInterval);
                console.error('Error hiding OpenEmu dashboard:', error);
            }
        } finally {
            hideInProgress = false;
        }
    }, 1000);
}

function normalizeTitleForMatch(title) {
    return title
        .toLowerCase()
        .replace(/\.[^/.]+$/, '')
        .replace(/\s*\(.*?\)/g, '')
        .replace(/,\s*the\b/g, '')
        .replace(/\bthe\b/g, ' ')
        .replace(/[^a-z0-9]+/g, ' ')
        .trim()
        .replace(/\s+/g, ' ');
}

function buildDolphinThumbnailMap() {
    const thumbnailDir = path.join(__dirname, 'assets', 'dolphin');
    const map = new Map();

    if (!fs.existsSync(thumbnailDir)) {
        return map;
    }

    const thumbnailFiles = fs.readdirSync(thumbnailDir, { withFileTypes: true });
    for (const file of thumbnailFiles) {
        if (!file.isFile() || path.extname(file.name).toLowerCase() !== '.png') {
            continue;
        }

        const basename = path.basename(file.name, '.png');
        map.set(normalizeTitleForMatch(basename), file.name);
    }

    return map;
}

function getNativeGames(recentGames) {
    return NATIVE_GAMES
        .filter(game => fs.existsSync(game.path) && fs.existsSync(game.appPath))
        .map(game => ({
            ...game,
            img: game.thumbnail && fs.existsSync(path.join(__dirname, 'assets', 'native', game.thumbnail))
                ? `/assets/native/${encodeURIComponent(game.thumbnail)}`
                : null,
            lastPlayed: recentGames[game.path] || 0
        }));
}

// Serve static files from the EmuBoard frontend directory
app.use(express.static(__dirname));

// Serve actual OpenEmu artwork directory
app.use('/artwork', express.static(ARTWORK_DIR));

// Load DB Map
function getArtworkMap() {
    try {
        const map = {};
        
        // 1. By Title (Fallback)
        const queryTitle = 'SELECT ZGAME.ZGAMETITLE, ZIMAGE.ZRELATIVEPATH FROM ZGAME LEFT JOIN ZIMAGE ON ZGAME.ZBOXIMAGE = ZIMAGE.Z_PK;';
        const stdoutTitle = execSync(`sqlite3 "${DB_PATH}" "${queryTitle}"`, { encoding: 'utf-8' });
        stdoutTitle.split('\n').forEach(line => {
             const parts = line.split('|');
             if(parts.length === 2 && parts[0] && parts[1]) {
                 map[parts[0].trim().toLowerCase()] = parts[1].trim();
             }
        });

        // 2. By Filename (More robust, covers N64 where titles are often missing)
        const queryRom = 'SELECT ZROM.ZLOCATION, ZIMAGE.ZRELATIVEPATH FROM ZROM JOIN ZGAME ON ZROM.ZGAME = ZGAME.Z_PK LEFT JOIN ZIMAGE ON ZGAME.ZBOXIMAGE = ZIMAGE.Z_PK;';
        const stdoutRom = execSync(`sqlite3 "${DB_PATH}" "${queryRom}"`, { encoding: 'utf-8' });
        stdoutRom.split('\n').forEach(line => {
             const parts = line.split('|');
             if(parts.length === 2 && parts[0] && parts[1]) {
                 try {
                     const decodedLocation = decodeURIComponent(parts[0].trim());
                     const filename = path.basename(decodedLocation);
                     map[filename] = parts[1].trim();
                 } catch (err) {}
             }
        });

        return map;
    } catch(e) {
        console.error("Failed to read sqlite:", e);
        return {};
    }
}

// Endpoint to scan and get all games
app.get('/api/games', (req, res) => {
    try {
        const games = [];
        const artworkMap = getArtworkMap(); // refresh on load in case of new games
        const recentGames = getRecentGames();

        // Scan OpenEmu Games
        if (fs.existsSync(GAMES_DIR)) {
            const entries = fs.readdirSync(GAMES_DIR, { withFileTypes: true });
            for (const entry of entries) {
                if (entry.isDirectory()) {
                    const gameFolderPath = path.join(GAMES_DIR, entry.name);
                    const filesInGameFolder = fs.readdirSync(gameFolderPath);
                    
                    const romFile = filesInGameFolder.find(f => 
                        !f.endsWith('.txt') && 
                        !f.startsWith('.DS_Store')
                    );

                    if (romFile) {
                        const romPath = path.join(gameFolderPath, romFile);
                        const cleanTitle = entry.name.replace(/\s*\(.*?\)/g, '').trim().toLowerCase();
                        const cleanTitleAlt = cleanTitle.replace(/\s*-\s*/g, ': ');
                        
                        let imageUuid = artworkMap[romFile] || artworkMap[cleanTitle] || artworkMap[cleanTitleAlt];
                        
                        games.push({
                            id: entry.name,
                            title: entry.name,
                            path: romPath,
                            img: imageUuid ? `/artwork/${imageUuid}` : null,
                            emulator: 'OpenEmu',
                            lastPlayed: recentGames[romPath] || 0
                        });
                    }
                }
            }
        }

        // Scan Dolphin Games
        if (fs.existsSync(DOLPHIN_GAMES_DIR)) {
            const dolphinThumbnailMap = buildDolphinThumbnailMap();
            const entries = fs.readdirSync(DOLPHIN_GAMES_DIR, { withFileTypes: true });
            for (const entry of entries) {
                if (entry.isFile() && !entry.name.startsWith('.DS_Store')) {
                    const title = entry.name.replace(/\.[^/.]+$/, "").replace(/\s*\(.*?\)/g, '').trim();
                    const thumbnailFile = dolphinThumbnailMap.get(normalizeTitleForMatch(title));
                    const imgUrl = thumbnailFile ? `/assets/dolphin/${encodeURIComponent(thumbnailFile)}` : null;
                    
                    const romPath = path.join(DOLPHIN_GAMES_DIR, entry.name);
                    games.push({
                        id: entry.name,
                        title: title,
                        path: romPath,
                        img: imgUrl,
                        emulator: 'Dolphin',
                        lastPlayed: recentGames[romPath] || 0
                    });
                }
            }
        }

        games.push(...getNativeGames(recentGames));

        res.json(games);
    } catch (error) {
        console.error("Error scanning games:", error);
        res.status(500).json({ error: "Failed to scan games" });
    }
});

// Endpoint to launch Native Emulator
app.post('/api/launch', async (req, res) => {
    const romPath = req.body.path;
    const emulator = req.body.emulator || 'OpenEmu';
    const { appName, appPath } = getEmulatorAppConfig(emulator);
    
    if (!romPath) {
        return res.status(400).json({ error: "No rom path provided" });
    }

    updateRecentGame(romPath);

    try {
        stopShutdownWatcher(appName);
        await quitOtherEmulators(emulator);

        if (emulator === 'Dolphin') {
            console.log(`Starting Dolphin with game: ${romPath}`);
            // Run Dolphin in batch mode (-b) so it closes entirely when the game ends,
            // and specify the file to execute (-e)
            await openApp(appPath, ['--args', '-b', '-e', romPath]);
            return res.json({ success: true, message: "Game launched in Dolphin!" });
        }

        if (emulator === 'soh') {
            console.log('Starting Ship of Harkinian');
            await openApp(appPath);
            maybeMonitorEmulatorAutoQuit(emulator);
            return res.json({ success: true, message: "Game launched in Ship of Harkinian!" });
        }

        if (emulator === '2s2h') {
            console.log('Starting 2 Ship 2 Harkinian');
            await openApp(appPath);
            maybeMonitorEmulatorAutoQuit(emulator);
            return res.json({ success: true, message: "Game launched in 2 Ship 2 Harkinian!" });
        }

        console.log(`Starting OpenEmu with game: ${romPath}`);
        await openApp(appPath, [romPath]);
        maybeMonitorEmulatorAutoQuit(emulator);
        scheduleOpenEmuLibraryClose();
        return res.json({ success: true, message: "Game launched in OpenEmu!" });
    } catch (error) {
        console.error(`Exec Error: ${error}`);
        return res.status(500).json({ error: error.message });
    }
});

app.listen(PORT, HOST, () => {
    console.log(`EmuBoard Backend running at http://${HOST}:${PORT}`);
});
