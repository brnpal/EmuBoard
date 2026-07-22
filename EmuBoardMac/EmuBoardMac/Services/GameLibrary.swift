import AppKit
import Foundation

@MainActor
final class GameLibrary: ObservableObject {
    @Published private(set) var games: [Game] = []
    @Published var selection: LibraryDestination = .home
    @Published var selectedGame: Game?
    @Published var searchText = ""
    @Published private(set) var isLoading = false

    let settings = AppSettings()
    let launcher = GameLauncher()
    private let scanner = LibraryScanner()

    init() {
        Task { await refresh() }
    }

    var filteredGames: [Game] {
        var source: [Game]
        switch selection {
        case .favorites: source = games.filter(\.isFavorite)
        default: source = games
        }
        guard !searchText.isEmpty else { return source }
        return source.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.system.localizedCaseInsensitiveContains(searchText) ||
            $0.emulator.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var recentGames: [Game] {
        games.filter { $0.lastPlayed != nil }
            .sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
            .prefix(12).map { $0 }
    }

    var favoriteGames: [Game] { games.filter(\.isFavorite) }

    var featuredGame: Game? {
        selectedGame ?? recentGames.first ?? games.first
    }

    var systems: [(name: String, games: [Game])] {
        Dictionary(grouping: games, by: \.system)
            .map { ($0.key, $0.value) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        let openEmu = settings.openEmuGamesDirectory
        let dolphin = settings.dolphinGamesDirectory
        let favorites = settings.favoritePaths
        let recents = settings.recentDates
        let scanned = await Task.detached(priority: .userInitiated) { [scanner] in
            scanner.scan(openEmuDirectory: openEmu, dolphinDirectory: dolphin, favorites: favorites, recents: recents)
        }.value
        games = scanned
        if let selectedGame { self.selectedGame = games.first { $0.id == selectedGame.id } }
        isLoading = false
    }

    func launch(_ game: Game) {
        selectedGame = game
        Task {
            guard await launcher.launch(game) else { return }
            var recents = settings.recentDates
            recents[game.fileURL.path] = Date()
            settings.recentDates = recents
            if let index = games.firstIndex(where: { $0.id == game.id }) {
                games[index].lastPlayed = recents[game.fileURL.path]
                selectedGame = games[index]
            }
        }
    }

    func launchSelected() {
        guard let selectedGame else { return }
        launch(selectedGame)
    }

    func toggleFavorite(_ game: Game) {
        var favorites = settings.favoritePaths
        if favorites.contains(game.fileURL.path) {
            favorites.remove(game.fileURL.path)
        } else {
            favorites.insert(game.fileURL.path)
        }
        settings.favoritePaths = favorites
        if let index = games.firstIndex(where: { $0.id == game.id }) {
            games[index].isFavorite.toggle()
            selectedGame = games[index]
        }
    }

    func toggleFavoriteForSelectedGame() {
        guard let selectedGame else { return }
        toggleFavorite(selectedGame)
    }
}
