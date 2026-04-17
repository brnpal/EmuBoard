const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { exec, execSync } = require('child_process');

const app = express();
const PORT = 8080;
const GAMES_DIR = '/Users/brendanallaway/Documents/openemu games';
const DOLPHIN_GAMES_DIR = '/Users/brendanallaway/Documents/Dolphin Games';
const ARTWORK_DIR = '/Users/brendanallaway/Library/Application Support/OpenEmu/Game Library/Artwork';
const DB_PATH = '/Users/brendanallaway/Library/Application Support/OpenEmu/Game Library/Library.storedata';

app.use(cors());
app.use(express.json());

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
                        const cleanTitle = entry.name.replace(/\s*\(.*?\)/g, '').trim().toLowerCase();
                        const cleanTitleAlt = cleanTitle.replace(/\s*-\s*/g, ': ');
                        
                        let imageUuid = artworkMap[romFile] || artworkMap[cleanTitle] || artworkMap[cleanTitleAlt];
                        
                        games.push({
                            id: entry.name,
                            title: entry.name,
                            path: path.join(gameFolderPath, romFile),
                            img: imageUuid ? `/artwork/${imageUuid}` : null,
                            emulator: 'OpenEmu'
                        });
                    }
                }
            }
        }

        // Scan Dolphin Games
        if (fs.existsSync(DOLPHIN_GAMES_DIR)) {
            const entries = fs.readdirSync(DOLPHIN_GAMES_DIR, { withFileTypes: true });
            for (const entry of entries) {
                if (entry.isFile() && !entry.name.startsWith('.DS_Store')) {
                    const title = entry.name.replace(/\.[^/.]+$/, "").replace(/\s*\(.*?\)/g, '').trim();
                    const thumbnailPath = path.join(__dirname, 'assets', 'dolphin', `${title}.png`);
                    const imgUrl = fs.existsSync(thumbnailPath) ? `/assets/dolphin/${encodeURIComponent(title)}.png` : null;
                    
                    games.push({
                        id: entry.name,
                        title: title,
                        path: path.join(DOLPHIN_GAMES_DIR, entry.name),
                        img: imgUrl,
                        emulator: 'Dolphin'
                    });
                }
            }
        }

        res.json(games);
    } catch (error) {
        console.error("Error scanning games:", error);
        res.status(500).json({ error: "Failed to scan games" });
    }
});

// Endpoint to launch Native Emulator
app.post('/api/launch', (req, res) => {
    const romPath = req.body.path;
    const emulator = req.body.emulator || 'OpenEmu';
    
    if (!romPath) {
        return res.status(400).json({ error: "No rom path provided" });
    }

    if (emulator === 'Dolphin') {
        console.log(`Starting Dolphin with game: ${romPath}`);
        // Run Dolphin in batch mode (-b) so it closes entirely when the game ends,
        // and specify the file to execute (-e)
        exec(`open -a "Dolphin" --args -b -e "${romPath}"`, (error, stdout, stderr) => {
            if (error) {
                console.error(`Exec Error: ${error}`);
                return res.status(500).json({ error: error.message });
            }
            res.json({ success: true, message: "Game launched in Dolphin!" });
        });
    } else {
        console.log(`Starting OpenEmu with game: ${romPath}`);
        
        // Using open -a to launch specific macOS app with arguments
        // Must quote the path to avoid issues with spaces
        exec(`open -a "OpenEmu" "${romPath}"`, (error, stdout, stderr) => {
            if (error) {
                console.error(`Exec Error: ${error}`);
                return res.status(500).json({ error: error.message });
            }
            
            // Automatically close the OpenEmu Library Dashboard, leaving only the game window
            setTimeout(() => {
                const script = `
                    tell application "System Events"
                        tell process "OpenEmu"
                            if exists window "OpenEmu" then
                                click button 1 of window "OpenEmu"
                            end if
                        end tell
                    end tell
                `;
                exec(`osascript -e '${script}'`, (scriptErr) => {
                    if (scriptErr) console.error("Error hiding OpenEmu dashboard:", scriptErr);
                });
            }, 2000);

            res.json({ success: true, message: "Game launched in OpenEmu!" });
        });
    }
});

app.listen(PORT, () => {
    console.log(`EmuBoard Backend running at http://localhost:${PORT}`);
});
