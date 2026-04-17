const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { exec, execSync } = require('child_process');

const app = express();
const PORT = 8080;
const GAMES_DIR = '/Users/brendanallaway/Documents/openemu games';
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
        const query = 'SELECT ZGAME.ZGAMETITLE, ZIMAGE.ZRELATIVEPATH FROM ZGAME LEFT JOIN ZIMAGE ON ZGAME.ZBOXIMAGE = ZIMAGE.Z_PK;';
        const stdout = execSync(`sqlite3 "${DB_PATH}" "${query}"`, { encoding: 'utf-8' });
        const map = {};
        stdout.split('\n').forEach(line => {
             const parts = line.split('|');
             if(parts.length === 2 && parts[0]) {
                 map[parts[0].trim().toLowerCase()] = parts[1].trim();
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
        
        if (!fs.existsSync(GAMES_DIR)) {
            return res.json([]);
        }

        const entries = fs.readdirSync(GAMES_DIR, { withFileTypes: true });
        const artworkMap = getArtworkMap(); // refresh on load in case of new games

        for (const entry of entries) {
            // Check if it's a directory (game folders from Vimm's Lair)
            if (entry.isDirectory()) {
                const gameFolderPath = path.join(GAMES_DIR, entry.name);
                const filesInGameFolder = fs.readdirSync(gameFolderPath);
                
                // Find the actual ROM file (ignore typical text files)
                const romFile = filesInGameFolder.find(f => 
                    !f.endsWith('.txt') && 
                    !f.startsWith('.DS_Store')
                );

                if (romFile) {
                    const cleanTitle = entry.name.replace(/\s*\(.*?\)/g, '').trim().toLowerCase();
                    // Some games might have subtitles replaced with colons in the DB, let's also try splitting by hyphen
                    const cleanTitleAlt = cleanTitle.replace(/\s*-\s*/g, ': ');
                    
                    let imageUuid = artworkMap[cleanTitle] || artworkMap[cleanTitleAlt];
                    
                    games.push({
                        id: entry.name,
                        title: entry.name, // The folder name
                        path: path.join(gameFolderPath, romFile),
                        // provide artwork path if found
                        img: imageUuid ? `/artwork/${imageUuid}` : null
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

// Endpoint to launch Native OpenEmu
app.post('/api/launch', (req, res) => {
    const romPath = req.body.path;
    
    if (!romPath) {
        return res.status(400).json({ error: "No rom path provided" });
    }

    console.log(`Starting OpenEmu with game: ${romPath}`);
    
    // Using open -a to launch specific macOS app with arguments
    // Must quote the path to avoid issues with spaces
    exec(`open -a "OpenEmu" "${romPath}"`, (error, stdout, stderr) => {
        if (error) {
            console.error(`Exec Error: ${error}`);
            return res.status(500).json({ error: error.message });
        }
        res.json({ success: true, message: "Game launched in OpenEmu!" });
    });
});

app.listen(PORT, () => {
    console.log(`EmuBoard Backend running at http://localhost:${PORT}`);
});
