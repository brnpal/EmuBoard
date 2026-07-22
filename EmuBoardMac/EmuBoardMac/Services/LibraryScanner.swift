import Foundation
import SQLite3

struct LibraryScanner: @unchecked Sendable {
    private let fileManager = FileManager.default

    func scan(openEmuDirectory: URL, dolphinDirectory: URL, favorites: Set<String>, recents: [String: Date]) -> [Game] {
        var results = scanOpenEmu(at: openEmuDirectory, favorites: favorites, recents: recents)
        results.append(contentsOf: scanDolphin(at: dolphinDirectory, favorites: favorites, recents: recents))
        results.append(contentsOf: scanNativePorts(favorites: favorites, recents: recents))
        return results.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func scanOpenEmu(at root: URL, favorites: Set<String>, recents: [String: Date]) -> [Game] {
        guard let folders = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }
        let artwork = openEmuArtworkMap()
        let excludedExtensions = ["txt", "nfo", "jpg", "jpeg", "png"]

        return folders.compactMap { folder in
            guard (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                  let files = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]),
                  let rom = files.first(where: { !excludedExtensions.contains($0.pathExtension.lowercased()) }) else { return nil }

            let title = cleanTitle(folder.lastPathComponent)
            let relativeArtwork = artwork[rom.lastPathComponent] ?? artwork[normalize(title)]
            let artworkURL = relativeArtwork.map { openEmuArtworkDirectory.appendingPathComponent($0) }
            return Game(
                id: rom.path,
                title: title,
                fileURL: rom,
                artworkURL: artworkURL,
                emulator: .openEmu,
                system: systemName(for: rom.pathExtension),
                lastPlayed: recents[rom.path],
                isFavorite: favorites.contains(rom.path)
            )
        }
    }

    private func scanDolphin(at root: URL, favorites: Set<String>, recents: [String: Date]) -> [Game] {
        let supported = ["iso", "gcm", "ciso", "wbfs", "rvz", "wia", "dol", "elf"]
        guard let files = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }

        return files.compactMap { rom in
            guard supported.contains(rom.pathExtension.lowercased()) else { return nil }
            let title = cleanTitle(rom.deletingPathExtension().lastPathComponent)
            return Game(
                id: rom.path,
                title: title,
                fileURL: rom,
                artworkURL: bundledArtwork(for: title, subdirectory: "assets/dolphin"),
                emulator: .dolphin,
                system: dolphinSystem(for: rom),
                lastPlayed: recents[rom.path],
                isFavorite: favorites.contains(rom.path)
            )
        }
    }

    private func scanNativePorts(favorites: Set<String>, recents: [String: Date]) -> [Game] {
        let definitions: [(String, String, String, EmulatorKind, String)] = [
            ("The Legend of Zelda: Ocarina of Time", "/Applications/soh.app", "ocarina-of-time.jpg", .shipOfHarkinian, "Nintendo 64 • Native Port"),
            ("The Legend of Zelda: Majora's Mask", "/Applications/2s2h.app", "majoras-mask.jpg", .twoShipTwoHarkinian, "Nintendo 64 • Native Port"),
            ("The Legend of Zelda: Twilight Princess", "/Applications/Dusklight.app", "twilight-princess.png", .dusklight, "GameCube • Native Port")
        ]

        return definitions.compactMap { title, path, artworkName, emulator, system in
            let url = URL(fileURLWithPath: path)
            guard fileManager.fileExists(atPath: path) else { return nil }
            return Game(
                id: path,
                title: title,
                fileURL: url,
                artworkURL: Bundle.main.url(forResource: artworkName, withExtension: nil, subdirectory: "assets/native"),
                emulator: emulator,
                system: system,
                lastPlayed: recents[path],
                isFavorite: favorites.contains(path)
            )
        }
    }

    private var openEmuSupportDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("OpenEmu/Game Library")
    }

    private var openEmuArtworkDirectory: URL { openEmuSupportDirectory.appendingPathComponent("Artwork") }

    private func openEmuArtworkMap() -> [String: String] {
        let databaseURL = openEmuSupportDirectory.appendingPathComponent("Library.storedata")
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let database else { return [:] }
        defer { sqlite3_close(database) }

        var result: [String: String] = [:]
        let query = """
            SELECT ZROM.ZFILENAME, ZROM.ZLOCATION, ZGAME.ZGAMETITLE, ZIMAGE.ZRELATIVEPATH
            FROM ZROM JOIN ZGAME ON ZROM.ZGAME = ZGAME.Z_PK
            LEFT JOIN ZIMAGE ON ZGAME.ZBOXIMAGE = ZIMAGE.Z_PK
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK, let statement else { return result }
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let artwork = sqliteString(statement, 3), !artwork.isEmpty else { continue }
            if let filename = sqliteString(statement, 0) { result[filename] = artwork }
            if let location = sqliteString(statement, 1),
               let decoded = location.removingPercentEncoding {
                result[URL(fileURLWithPath: decoded).lastPathComponent] = artwork
            }
            if let title = sqliteString(statement, 2) { result[normalize(title)] = artwork }
        }
        return result
    }

    private func sqliteString(_ statement: OpaquePointer, _ column: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: pointer)
    }

    private func bundledArtwork(for title: String, subdirectory: String) -> URL? {
        guard let directory = Bundle.main.resourceURL?.appendingPathComponent(subdirectory),
              let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return nil }
        return files.first { normalize($0.deletingPathExtension().lastPathComponent) == normalize(title) }
    }

    private func cleanTitle(_ value: String) -> String {
        value.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalize(_ value: String) -> String {
        cleanTitle(value)
            .lowercased()
            .replacingOccurrences(of: ", the", with: "")
            .replacingOccurrences(of: "the ", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func systemName(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "nes": "Nintendo Entertainment System"
        case "sfc", "smc": "Super Nintendo"
        case "n64", "z64", "v64": "Nintendo 64"
        case "gb": "Game Boy"
        case "gbc": "Game Boy Color"
        case "gba": "Game Boy Advance"
        case "nds": "Nintendo DS"
        case "gen", "md": "Sega Genesis"
        case "cue", "chd", "pbp": "PlayStation"
        default: "OpenEmu"
        }
    }

    private func dolphinSystem(for rom: URL) -> String {
        rom.pathExtension.lowercased() == "wbfs" ? "Nintendo Wii" : "Nintendo GameCube / Wii"
    }
}
