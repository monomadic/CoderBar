import SwiftUI
import AppKit
import CoderBarKit

@main
@MainActor
enum CoderBarApp {
    static func main() {
        // Acquire before AppModel starts hooks, login services, or creates windows.
        let lockURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CoderBar/instance.lock")
        do {
            guard let instance = try ProcessInstanceLock(url: lockURL) else {
                NSLog("CoderBar is already running; ignoring duplicate launch")
                return
            }
            let application = NSApplication.shared
            let delegate = AppDelegate()
            application.delegate = delegate
            application.setActivationPolicy(.accessory)
            withExtendedLifetime((instance, delegate)) {
                application.run()
            }
        } catch {
            NSLog("Cannot acquire CoderBar instance lock: %@", String(describing: error))
            exit(EXIT_FAILURE)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppModel.shared.islandController?.show()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppModel.shared.shutdown()
    }
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var settingsWindow: NSWindow?

    func show(model: AppModel) {
        if let settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }

        let rootView = SettingsView().environmentObject(model)
        let hostingView = NSHostingView(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CoderBar"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        settingsWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        settingsWindow = nil
    }
}
