import Cocoa
import SwiftUI

@MainActor
final class RecordingIndicator {
    private var panel: NSPanel?

    func show(_ label: String, color: Color) {
        hide()
        let view = HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())

        let hosting = NSHostingView(rootView: view)
        hosting.frame.size = hosting.fittingSize
        let panel = NSPanel(contentRect: hosting.frame,
                            styleMask: [.nonactivatingPanel, .borderless],
                            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.contentView = hosting
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.midX - hosting.frame.width / 2, y: f.minY + 60))
        }
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}
