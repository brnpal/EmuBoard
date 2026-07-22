import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: GameLibrary

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            MainLibraryView()
        }
        .background(Color(red: 0.035, green: 0.035, blue: 0.055))
        .searchable(text: $library.searchText, placement: .toolbar, prompt: "Games, systems, or emulators")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if library.isLoading {
                    ProgressView().controlSize(.small)
                }
                Button {
                    Task { await library.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh Library (⌘R)")
            }
        }
        .overlay(alignment: .top) {
            LauncherStatusView(launcher: library.launcher)
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var library: GameLibrary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LogoMark()
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 26)

            List(selection: $library.selection) {
                Section {
                    ForEach(LibraryDestination.allCases) { destination in
                        Label(destination.rawValue, systemImage: destination.symbol)
                            .tag(destination)
                    }
                }

                if !library.systems.isEmpty {
                    Section("SYSTEMS") {
                        ForEach(library.systems.prefix(7), id: \.name) { system in
                            HStack {
                                Text(system.name).lineLimit(1)
                                Spacer()
                                Text("\(system.games.count)")
                                    .foregroundStyle(.tertiary)
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Spacer(minLength: 10)

            HStack(spacing: 9) {
                Circle()
                    .fill(library.games.isEmpty ? Color.orange : Color.green)
                    .frame(width: 7, height: 7)
                Text(library.games.isEmpty ? "No games found" : "\(library.games.count) games ready")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
        }
        .background(.ultraThinMaterial)
    }
}

private struct MainLibraryView: View {
    @EnvironmentObject private var library: GameLibrary

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.035, blue: 0.055).ignoresSafeArea()
            if library.isLoading && library.games.isEmpty {
                VStack(spacing: 15) {
                    ProgressView().controlSize(.large)
                    Text("Building your library…").foregroundStyle(.secondary)
                }
            } else if library.games.isEmpty {
                EmptyLibraryView()
            } else {
                ScrollView {
                    switch library.selection {
                    case .home: HomeView()
                    case .library: GameGridView(title: "All Games", games: library.filteredGames)
                    case .favorites: GameGridView(title: "Favorites", games: library.filteredGames)
                    case .systems: SystemsView()
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

private struct HomeView: View {
    @EnvironmentObject private var library: GameLibrary

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 38) {
            if let featured = library.featuredGame {
                HeroView(game: featured)
                    .padding(.horizontal, 26)
                    .padding(.top, 20)
                    .id(featured.id)
                    .transition(.opacity)
            }

            if !library.searchText.isEmpty {
                GameShelf(title: "Search Results", games: library.filteredGames)
            } else {
                if !library.recentGames.isEmpty {
                    GameShelf(title: "Jump Back In", subtitle: "Your recently played games", games: library.recentGames)
                }
                if !library.favoriteGames.isEmpty {
                    GameShelf(title: "Favorites", games: library.favoriteGames)
                }
                GameShelf(title: "The Complete Library", subtitle: "Every world, ready to launch", games: library.games)
            }
        }
        .padding(.bottom, 46)
    }
}

private struct GameShelf: View {
    let title: String
    var subtitle: String? = nil
    let games: [Game]

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 22, weight: .bold, design: .rounded))
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 32)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 18) {
                    ForEach(games) { game in GameCard(game: game) }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 10)
            }
        }
    }
}

private struct GameGridView: View {
    let title: String
    let games: [Game]
    private let columns = [GridItem(.adaptive(minimum: 174, maximum: 200), spacing: 22, alignment: .top)]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(title)
                .font(.system(size: 30, weight: .black, design: .rounded))
            if games.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.badge.minus")
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("Nothing here yet").font(.title2.bold())
                    Text("Try another search or add a favorite.").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 350)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
                    ForEach(games) { game in GameCard(game: game) }
                }
            }
        }
        .padding(32)
    }
}

private struct SystemsView: View {
    @EnvironmentObject private var library: GameLibrary

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 42) {
            Text("Systems")
                .font(.system(size: 30, weight: .black, design: .rounded))
            ForEach(library.systems, id: \.name) { system in
                GameShelf(title: system.name, subtitle: "\(system.games.count) \(system.games.count == 1 ? "game" : "games")", games: system.games)
                    .padding(.horizontal, -32)
            }
        }
        .padding(32)
    }
}

private struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.purple)
            Text("Your library is waiting")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text("Choose your OpenEmu and Dolphin game folders in Settings, then refresh the library.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Label("Open Settings", systemImage: "gear")
            }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LauncherStatusView: View {
    @ObservedObject var launcher: GameLauncher

    var body: some View {
        Group {
            if let game = launcher.activeGameTitle {
                Label("Now playing \(game)", systemImage: "waveform")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.12)))
                    .padding(.top, 9)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35), value: launcher.activeGameTitle)
        .alert("EmuBoard", isPresented: Binding(
            get: { launcher.alertMessage != nil },
            set: { if !$0 { launcher.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { launcher.alertMessage = nil }
        } message: {
            Text(launcher.alertMessage ?? "")
        }
    }
}
