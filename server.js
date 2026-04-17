const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const app = express();
const PORT = 8080;
const GAMES_DIR = '/Users/brendanallaway/Documents/openemu games';

app.use(cors());
app.use(express.json());

// Serve static files from the EmuBoard frontend directory
app.use(express.static(__dirname));

// Endpoint to scan and get all games
app.get('/api/games', (req, res) => {
    try {
        const games = [];
        
        // Ensure directory exists
        if (!fs.existsSync(GAMES_DIR)) {
            return res.json([]);
        }

        const entries = fs.readdirSync(GAMES_DIR, { withFileTypes: true });

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
                    games.push({
                        id: entry.name,
                        title: entry.name, // The folder name is usually the clean game title
                        path: path.join(gameFolderPath, romFile)
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
