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

    private var screen: NSScreen {
        NSScreen.main ?? NSScreen.screens[0]
    }

    func show(_ label: String, color: Color) {
        state.label = label
        state.color = color

        if let notch {
            Task { await notch.compact(on: screen) }
            return
        }

        let state = self.state
        let newNotch = DynamicNotch(
            hoverBehavior: [],
            style: .auto,
            expanded: { ExpandedContent(state: state) },
            compactLeading: { CompactDot(state: state) },
            compactTrailing: { CompactLabel(state: state) }
        )
        notch = newNotch
        Task { await newNotch.compact(on: screen) }
    }

    func hide() {
        guard let notch else { return }
        Task { await notch.hide() }
    }
}
