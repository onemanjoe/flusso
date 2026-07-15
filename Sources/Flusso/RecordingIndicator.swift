import Cocoa
import SwiftUI
import DynamicNotchKit

@MainActor
final class RecordingIndicator {
    private final class State: ObservableObject {
        @Published var label = ""
        @Published var color = Color.red
    }

    private struct CompactDot: View {
        @ObservedObject var state: State

        var body: some View {
            Circle()
                .fill(state.color)
                .frame(width: 8, height: 8)
        }
    }

    private struct CompactLabel: View {
        @ObservedObject var state: State

        var body: some View {
            Text(state.label)
                .font(.system(size: 12, weight: .medium))
                .fixedSize()
        }
    }

    private struct ExpandedContent: View {
        @ObservedObject var state: State

        var body: some View {
            HStack(spacing: 8) {
                Circle().fill(state.color).frame(width: 10, height: 10)
                Text(state.label).font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private let state = State()
    private var notch: DynamicNotch<ExpandedContent, CompactDot, CompactLabel>?

    // The screen the user is currently working on (keyboard focus), falling back
    // to the primary screen. This is where the indicator should appear.
    private var screen: NSScreen {
        NSScreen.main ?? NSScreen.screens[0]
    }

    // Mirrors DynamicNotchKit's own `.auto` detection (auxiliaryTop*Area), so our
    // choice below always matches the style the library resolves for this screen.
    private func hasNotch(_ screen: NSScreen) -> Bool {
        screen.auxiliaryTopLeftArea?.width != nil && screen.auxiliaryTopRightArea?.width != nil
    }

    func show(_ label: String, color: Color) {
        state.label = label
        state.color = color

        let screen = self.screen
        let notch = notch ?? makeNotch()
        self.notch = notch

        // On a notched screen we hug the notch (compact). On any screen WITHOUT a
        // notch (external monitor, or clamshell) DynamicNotchKit parks the compact
        // renderer off-screen, so we must expand into a floating pill instead —
        // otherwise the indicator is invisible, which is what broke on the LG.
        Task {
            if hasNotch(screen) {
                await notch.compact(on: screen)
            } else {
                await notch.expand(on: screen)
            }
        }
    }

    func hide() {
        guard let notch else { return }
        Task { await notch.hide() }
    }

    private func makeNotch() -> DynamicNotch<ExpandedContent, CompactDot, CompactLabel> {
        let state = self.state
        return DynamicNotch(
            hoverBehavior: [],
            style: .auto,
            expanded: { ExpandedContent(state: state) },
            compactLeading: { CompactDot(state: state) },
            compactTrailing: { CompactLabel(state: state) }
        )
    }
}
