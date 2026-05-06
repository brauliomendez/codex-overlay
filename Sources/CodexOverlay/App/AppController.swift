import AppKit
import SwiftUI

@MainActor
final class AppController {
    static let shared = AppController()

    private var panel: OverlayPanel?
    private weak var model: OverlayViewModel?

    private init() {}

    func configure(model: OverlayViewModel) {
        self.model = model
    }

    func toggleOverlay() {
        if panel?.isVisible == true {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    func showOverlay() {
        let panel = panel ?? makePanel()
        self.panel = panel

        position(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hideOverlay() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> OverlayPanel {
        let viewModel = model ?? .shared
        let panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 430),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.minSize = NSSize(width: 640, height: 360)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        let rootView = OverlayView(onClose: { [weak panel] in
            panel?.orderOut(nil)
        })
        .environmentObject(viewModel)

        panel.contentView = NSHostingView(rootView: rootView)
        return panel
    }

    private func position(_ panel: NSPanel) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height - 96
        )
        panel.setFrameOrigin(origin)
    }
}

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
