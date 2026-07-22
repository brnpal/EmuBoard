import AppKit
import SwiftUI

struct ArtworkView: View {
    let game: Game
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let url = game.artworkURL, let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.16, green: 0.12, blue: 0.29), Color(red: 0.04, green: 0.08, blue: 0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.white.opacity(0.18))
                    Text(game.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(24)
                }
            }
        }
    }
}

struct LogoMark: View {
    var body: some View {
        HStack(spacing: 11) {
            if let url = Bundle.main.url(forResource: "emu_avatar", withExtension: "png", subdirectory: "assets"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
            } else {
                Image(systemName: "gamecontroller.fill")
                    .font(.title2)
                    .foregroundStyle(.purple)
            }

            Text("EMUBOARD")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .tracking(1.6)
        }
    }
}
