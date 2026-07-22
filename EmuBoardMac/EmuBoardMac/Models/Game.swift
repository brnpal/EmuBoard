import Foundation

enum EmulatorKind: String, Codable, CaseIterable, Sendable {
    case openEmu
    case dolphin
    case shipOfHarkinian
    case twoShipTwoHarkinian
    case dusklight

    var displayName: String {
        switch self {
        case .openEmu: "OpenEmu"
        case .dolphin: "Dolphin"
        case .shipOfHarkinian: "Ship of Harkinian"
        case .twoShipTwoHarkinian: "2 Ship 2 Harkinian"
        case .dusklight: "Dusklight"
        }
    }

    var appName: String {
        switch self {
        case .openEmu: "OpenEmu"
        case .dolphin: "Dolphin"
        case .shipOfHarkinian: "soh"
        case .twoShipTwoHarkinian: "2s2h"
        case .dusklight: "Dusklight"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .openEmu: "org.openemu.OpenEmu"
        case .dolphin: "org.dolphin-emu.dolphin"
        case .shipOfHarkinian: "com.shipofharkinian.ShipOfHarkinian"
        case .twoShipTwoHarkinian: "com.2ship2harkinian.2s2h"
        case .dusklight: "dev.twilitrealm.dusk"
        }
    }

    var accentName: String {
        switch self {
        case .openEmu: "indigo"
        case .dolphin: "cyan"
        case .shipOfHarkinian, .twoShipTwoHarkinian, .dusklight: "amber"
        }
    }
}

struct Game: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let fileURL: URL
    let artworkURL: URL?
    let emulator: EmulatorKind
    let system: String
    var lastPlayed: Date?
    var isFavorite: Bool

    var subtitle: String { "\(system)  •  \(emulator.displayName)" }
}

enum LibraryDestination: String, CaseIterable, Identifiable {
    case home = "Home"
    case library = "Library"
    case systems = "Systems"
    case favorites = "Favorites"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .home: "sparkles.rectangle.stack.fill"
        case .library: "square.grid.2x2.fill"
        case .systems: "gamecontroller.fill"
        case .favorites: "heart.fill"
        }
    }
}
