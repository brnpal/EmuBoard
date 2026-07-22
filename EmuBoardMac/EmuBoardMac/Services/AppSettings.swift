import AppKit
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let openEmuGames = "openEmuGamesDirectory"
        static let dolphinGames = "dolphinGamesDirectory"
        static let favorites = "favoriteGamePaths"
        static let recents = "recentGameDates"
    }

    @Published var openEmuGamesDirectory: URL {
        didSet { defaults.set(openEmuGamesDirectory.path, forKey: Key.openEmuGames) }
    }

    @Published var dolphinGamesDirectory: URL {
        didSet { defaults.set(dolphinGamesDirectory.path, forKey: Key.dolphinGames) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        openEmuGamesDirectory = URL(fileURLWithPath: defaults.string(forKey: Key.openEmuGames) ?? documents.appendingPathComponent("openemu games").path)
        dolphinGamesDirectory = URL(fileURLWithPath: defaults.string(forKey: Key.dolphinGames) ?? documents.appendingPathComponent("Dolphin Games").path)
    }

    var favoritePaths: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.favorites) ?? []) }
        set { defaults.set(Array(newValue), forKey: Key.favorites) }
    }

    var recentDates: [String: Date] {
        get {
            guard let data = defaults.data(forKey: Key.recents),
                  let value = try? JSONDecoder().decode([String: Date].self, from: data) else { return [:] }
            return value
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.recents)
        }
    }

    func chooseDirectory(title: String, current: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.directoryURL = current
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}
