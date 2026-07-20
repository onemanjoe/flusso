import Cocoa
import SwiftUI
import Combine
import DynamicNotchKit

/// One row in the notch history list.
struct IndicatorRow: Identifiable {
    let id = UUID()
    let snippet: String
    let time: String
    init(snippet: String, time: String) {
        self.snippet = snippet
        self.time = time
    }
}

@MainActor
final class RecordingIndicator {
    /// What the notch is currently showing.
    enum Kind { case listening, thinking, peek, history }

    private final class State: ObservableObject {
        @Published var kind: Kind = .listening
        @Published var label = ""
        @Published var color = Color.red
        @Published var level: Float = 0
        @Published var rows: [IndicatorRow] = []
        @Published var copied = false
        var onCopy: ((Int) -> Void)?
    }

    /// Five bars whose height follows the live level, hugging the notch or the pill.
    private struct Waveform: View {
        @ObservedObject var state: State
        private let mults: [CGFloat] = [0.45, 0.75, 1.0, 0.75, 0.45]
        var body: some View {
            HStack(spacing: 2) {
                ForEach(0..<mults.count, id: \.self) { i in
                    Capsule().fill(state.color)
                        .frame(width: 2.5, height: max(3, CGFloat(state.level) * 15 * mults[i]))
                }
            }
            .frame(height: 16)
            .animation(.easeOut(duration: 0.08), value: state.level)
        }
    }

    private struct CompactLeading: View {
        @ObservedObject var state: State
        var body: some View {
            switch state.kind {
            case .listening: Waveform(state: state)
            case .peek: Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            case .thinking, .history: Circle().fill(state.color).frame(width: 8, height: 8)
            }
        }
    }

    private struct CompactTrailing: View {
        @ObservedObject var state: State
        var body: some View {
            Text(state.kind == .peek ? "storico" : state.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(state.kind == .peek ? .secondary : .primary)
                .fixedSize()
        }
    }

    private struct ExpandedContent: View {
        @ObservedObject var state: State
        var body: some View {
            switch state.kind {
            case .history:
                VStack(alignment: .leading, spacing: 2) {
                    if state.copied {
                        Label("Copiato", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.green)
                            .padding(.vertical, 8).padding(.horizontal, 12)
                    } else if state.rows.isEmpty {
                        Text("Nessuna dettatura")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                            .padding(.vertical, 10).padding(.horizontal, 12)
                    } else {
                        ForEach(Array(state.rows.enumerated()), id: \.element.id) { idx, row in
                            Button { state.onCopy?(idx) } label: {
                                HStack(spacing: 8) {
                                    Text(row.snippet).font(.system(size: 12)).lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(row.time).font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 5).padding(.horizontal, 12)
                        }
                    }
                }
                .frame(width: 340)
                .padding(.vertical, 6)
            default:
                HStack(spacing: 8) {
                    if state.kind == .listening {
                        Waveform(state: state)
                    } else {
                        Circle().fill(state.color).frame(width: 10, height: 10)
                    }
                    if !state.label.isEmpty {
                        Text(state.label).font(.system(size: 13, weight: .medium))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
        }
    }

    var onHoverChange: ((Bool) -> Void)?

    private let state = State()
    private var notch: DynamicNotch<ExpandedContent, CompactLeading, CompactTrailing>?
    private var hoverCancellable: AnyCancellable?

    private var screen: NSScreen { NSScreen.main ?? NSScreen.screens[0] }

    private func hasNotch(_ screen: NSScreen) -> Bool {
        screen.auxiliaryTopLeftArea?.width != nil && screen.auxiliaryTopRightArea?.width != nil
    }

    func showListening() { state.kind = .listening; state.label = "Listening"; state.color = .red; present() }
    func showThinking() { state.kind = .thinking; state.label = "Thinking"; state.color = .orange; present() }
    func showPeek() { state.kind = .peek; state.label = ""; state.level = 0; present() }
    func setLevel(_ level: Float) { state.level = level }
    func flashCopied() { state.copied = true }

    func showHistory(_ rows: [IndicatorRow], onCopy: @escaping (Int) -> Void) {
        state.kind = .history
        state.rows = rows
        state.onCopy = onCopy
        state.copied = false
        let screen = self.screen
        let notch = notch ?? makeNotch()
        self.notch = notch
        // History is a dropdown list: always expand, on notch and non-notch screens.
        Task { await notch.expand(on: screen) }
    }

    func hide() {
        state.copied = false
        guard let notch else { return }
        Task { await notch.hide() }
    }

    /// Compact on a notched screen (hug the notch); expand into a floating pill on
    /// any screen without a notch, where the compact renderer is parked off-screen.
    private func present() {
        let screen = self.screen
        let notch = notch ?? makeNotch()
        self.notch = notch
        Task {
            if hasNotch(screen) { await notch.compact(on: screen) }
            else { await notch.expand(on: screen) }
        }
    }

    private func makeNotch() -> DynamicNotch<ExpandedContent, CompactLeading, CompactTrailing> {
        let state = self.state
        let n = DynamicNotch(
            hoverBehavior: [.keepVisible, .increaseShadow],
            style: .auto,
            expanded: { ExpandedContent(state: state) },
            compactLeading: { CompactLeading(state: state) },
            compactTrailing: { CompactTrailing(state: state) }
        )
        // Forward the library's hover state so AppState can open the history and
        // cancel the pending recording. removeDuplicates avoids repeat callbacks.
        hoverCancellable = n.$isHovering
            .removeDuplicates()
            .sink { [weak self] hovering in self?.onHoverChange?(hovering) }
        return n
    }
}
