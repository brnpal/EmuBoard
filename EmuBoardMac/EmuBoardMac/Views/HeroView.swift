import SwiftUI

struct HeroView: View {
    @EnvironmentObject private var library: GameLibrary
    let game: Game

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                ArtworkView(game: game)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .blur(radius: 1.2)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.035, green: 0.035, blue: 0.055).opacity(0.05), location: 0),
                                .init(color: Color(red: 0.035, green: 0.035, blue: 0.055).opacity(0.48), location: 0.5),
                                .init(color: Color(red: 0.035, green: 0.035, blue: 0.055), location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .overlay {
                        LinearGradient(colors: [Color(red: 0.035, green: 0.035, blue: 0.055).opacity(0.9), .clear], startPoint: .leading, endPoint: .trailing)
                    }

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 7) {
                        Text(game.system.uppercased())
                        Circle().frame(width: 3, height: 3)
                        Text(game.emulator.displayName.uppercased())
                    }
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.35)
                    .foregroundStyle(.white.opacity(0.72))

                    Text(game.title)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: 610, alignment: .leading)

                    Text("Ready when you are. EmuBoard will launch the right engine and take you directly into the game.")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineSpacing(3)
                        .frame(maxWidth: 520, alignment: .leading)

                    HStack(spacing: 12) {
                        Button {
                            library.launch(game)
                        } label: {
                            Label("Play", systemImage: "play.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 11)
                                .background(.white, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            library.toggleFavorite(game)
                        } label: {
                            Image(systemName: game.isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 42, height: 42)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.14)))
                        }
                        .buttonStyle(.plain)
                        .help(game.isFavorite ? "Remove from Favorites" : "Add to Favorites")
                    }
                }
                .padding(.leading, 44)
                .padding(.bottom, 42)
            }
        }
        .frame(height: 475)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.32), radius: 30, y: 14)
    }
}
