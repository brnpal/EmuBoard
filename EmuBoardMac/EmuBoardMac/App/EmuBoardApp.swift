import SwiftUI

@main
struct EmuBoardApp: App {
    @StateObject private var library = GameLibrary()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .frame(minWidth: 980, minHeight: 680)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh Library") {
                    Task { await library.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandMenu("Game") {
                Button("Play Selected Game") { library.launchSelected() }
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(library.selectedGame == nil)

                Button(library.selectedGame?.isFavorite == true ? "Remove from Favorites" : "Add to Favorites") {
                    library.toggleFavoriteForSelectedGame()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(library.selectedGame == nil)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(library)
        }
    }
}
