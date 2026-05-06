import AppKit
import Carbon
import SwiftUI

@main
struct CodexOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = OverlayViewModel.shared

    var body: some Scene {
        MenuBarExtra("Codex Overlay", systemImage: "sparkles") {
            Button("Show Overlay") {
                AppController.shared.showOverlay()
            }
            .keyboardShortcut(" ", modifiers: [.option])

            Button("Copy Last Response") {
                model.copyResponse()
            }
            .disabled(model.response.isEmpty)

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppController.shared.configure(model: .shared)
        hotKey = GlobalHotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)) {
            AppController.shared.toggleOverlay()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            AppController.shared.showOverlay()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKey?.unregister()
    }
}
