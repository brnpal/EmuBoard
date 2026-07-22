import AppKit
import ApplicationServices
import Foundation

@MainActor
final class GameLauncher: ObservableObject {
    @Published private(set) var launchingGameID: String?
    @Published private(set) var activeGameTitle: String?
    @Published var alertMessage: String?

    private var activeApplication: NSRunningApplication?

    func launch(_ game: Game) async -> Bool {
        guard launchingGameID == nil else { return false }
        launchingGameID = game.id
        defer { launchingGameID = nil }

        do {
            try await terminateOtherEmulators(except: game.emulator)
            let application = try await open(game)
            activeApplication = application
            activeGameTitle = game.title
            observeTermination(of: application)

            if game.emulator == .openEmu {
                scheduleOpenEmuLibrarySuppression()
            }
            return true
        } catch {
            alertMessage = "Couldn’t launch \(game.title).\n\n\(error.localizedDescription)"
            return false
        }
    }

    private func open(_ game: Game) async throws -> NSRunningApplication {
        let workspace = NSWorkspace.shared
        switch game.emulator {
        case .openEmu:
            guard let appURL = workspace.urlForApplication(withBundleIdentifier: game.emulator.bundleIdentifier) else {
                throw LaunchError.applicationMissing(game.emulator.displayName)
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            return try await workspace.open([game.fileURL], withApplicationAt: appURL, configuration: configuration)

        case .dolphin:
            guard let appURL = workspace.urlForApplication(withBundleIdentifier: game.emulator.bundleIdentifier) else {
                throw LaunchError.applicationMissing(game.emulator.displayName)
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.createsNewApplicationInstance = true
            configuration.arguments = ["-b", "-e", game.fileURL.path]
            return try await workspace.openApplication(at: appURL, configuration: configuration)

        case .shipOfHarkinian, .twoShipTwoHarkinian, .dusklight:
            let appURL = game.fileURL
            guard FileManager.default.fileExists(atPath: appURL.path) else {
                throw LaunchError.applicationMissing(game.emulator.displayName)
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            return try await workspace.openApplication(at: appURL, configuration: configuration)
        }
    }

    private func terminateOtherEmulators(except active: EmulatorKind) async throws {
        let knownBundleIDs = Set(EmulatorKind.allCases.map(\.bundleIdentifier)).subtracting([active.bundleIdentifier])
        let running = NSWorkspace.shared.runningApplications.filter { app in
            app.bundleIdentifier.map(knownBundleIDs.contains) == true
        }

        for app in running {
            app.terminate()
            for _ in 0..<20 where !app.isTerminated {
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            if !app.isTerminated { app.forceTerminate() }
        }
    }

    private func observeTermination(of application: NSRunningApplication) {
        let pid = application.processIdentifier
        Task { [weak self] in
            while !application.isTerminated {
                try? await Task.sleep(nanoseconds: 750_000_000)
            }
            guard self?.activeApplication?.processIdentifier == pid else { return }
            self?.activeApplication = nil
            self?.activeGameTitle = nil
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func scheduleOpenEmuLibrarySuppression() {
        Task {
            for _ in 0..<8 {
                try? await Task.sleep(nanoseconds: 650_000_000)
                guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: EmulatorKind.openEmu.bundleIdentifier).first else { continue }
                closeOpenEmuLibraryWindow(processIdentifier: app.processIdentifier)
            }
        }
    }

    private func closeOpenEmuLibraryWindow(processIdentifier: pid_t) {
        let application = AXUIElementCreateApplication(processIdentifier)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return }

        for window in windows {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
            guard let title = titleValue as? String, title == "OpenEmu" else { continue }
            var closeButtonValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &closeButtonValue) == .success,
                  let closeButton = closeButtonValue else { continue }
            AXUIElementPerformAction(closeButton as! AXUIElement, kAXPressAction as CFString)
        }
    }
}

private enum LaunchError: LocalizedError {
    case applicationMissing(String)

    var errorDescription: String? {
        switch self {
        case .applicationMissing(let name): "\(name) isn’t installed. Install it or update its location in Applications."
        }
    }
}
