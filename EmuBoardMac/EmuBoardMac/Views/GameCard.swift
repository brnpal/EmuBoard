import SwiftUI

struct GameCard: View {
    @EnvironmentObject private var library: GameLibrary
    let game: Game
    var height: CGFloat = 180
    var fallbackWidth: CGFloat = 174

    @State private var isHovered = false

    private var width: CGFloat {
        guard let image = ArtworkImageStore.image(at: game.artworkURL), image.size.height > 0 else {
            return fallbackWidth
        }
        return height * (image.size.width / image.size.height)
    }

    var body: some View {
        Button {
            library.launch(game)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    ArtworkView(game: game, contentMode: .fit)
                        .frame(width: width, height: height)
                        .background(.black.opacity(0.3))
                        .clipped()
                        .overlay(alignment: .bottom) {
                            LinearGradient(colors: [.clear, .black.opacity(0.42)], startPoint: .center, endPoint: .bottom)
                        }

                    if isHovered {
                        Image(systemName: "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 46, height: 46)
                            .background(.white, in: Circle())
                            .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if game.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.55), in: Circle())
                            .padding(8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(isHovered ? 0.28 : 0.08), lineWidth: 1)
                }
                .shadow(color: .black.opacity(isHovered ? 0.55 : 0.24), radius: isHovered ? 22 : 8, y: isHovered ? 12 : 5)

                VStack(alignment: .leading, spacing: 3) {
                    Text(game.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(game.system)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: width, alignment: .leading)
            }
            .scaleEffect(isHovered ? 1.035 : 1)
            .offset(y: isHovered ? -4 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Play") { library.launch(game) }
            Button(game.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                library.toggleFavorite(game)
            }
            Divider()
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([game.fileURL]) }
        }
        .accessibilityLabel("\(game.title), \(game.system)")
        .accessibilityHint("Play game")
    }
}
