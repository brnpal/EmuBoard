import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var library: GameLibrary

    var body: some View {
        Form {
            Section("Game Libraries") {
                DirectorySettingRow(
                    title: "OpenEmu Games",
                    url: library.settings.openEmuGamesDirectory
                ) {
                    if let url = library.settings.chooseDirectory(title: "Choose OpenEmu Games Folder", current: library.settings.openEmuGamesDirectory) {
                        library.settings.openEmuGamesDirectory = url
                        Task { await library.refresh() }
                    }
                }

                DirectorySettingRow(
                    title: "Dolphin Games",
                    url: library.settings.dolphinGamesDirectory
                ) {
                    if let url = library.settings.chooseDirectory(title: "Choose Dolphin Games Folder", current: library.settings.dolphinGamesDirectory) {
                        library.settings.dolphinGamesDirectory = url
                        Task { await library.refresh() }
                    }
                }
            }

            Section("Emulators") {
                ForEach(EmulatorKind.allCases, id: \.self) { emulator in
                    HStack {
                        Image(systemName: NSWorkspace.shared.urlForApplication(withBundleIdentifier: emulator.bundleIdentifier) == nil ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(NSWorkspace.shared.urlForApplication(withBundleIdentifier: emulator.bundleIdentifier) == nil ? .orange : .green)
                        Text(emulator.displayName)
                        Spacer()
                        Text(NSWorkspace.shared.urlForApplication(withBundleIdentifier: emulator.bundleIdentifier) == nil ? "Not found" : "Installed")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Text("EmuBoard launches each game directly through its optimized engine. Emulator library windows are skipped whenever the engine permits it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(width: 610, height: 460)
    }
}

private struct DirectorySettingRow: View {
    let title: String
    let url: URL
    let choose: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.medium)
                Text(url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button("Choose…", action: choose)
        }
    }
}
