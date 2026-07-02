import SwiftUI

struct MenuContent: View {
    @ObservedObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var statusLine: String {
        switch state.phase {
        case .starting: return "Starting..."
        case .needsSetup(let why): return why
        case .idle: return state.settings.paused ? "Paused" : "Ready, hold Fn and speak"
        case .recording: return "Listening..."
        case .processing: return "Thinking..."
        }
    }

    var body: some View {
        Text(statusLine)
        if let warning = state.lastWarning {
            Text(warning).font(.caption)
        }
        Divider()
        Button(state.settings.paused ? "Resume Flusso" : "Pause Flusso") { state.togglePaused() }
        Button("Copy Last Dictation") { state.copyLastDictation() }
        Divider()
        Button("Recent Dictations...") { openWindow(id: "history"); NSApp.activate() }
        Button("Personal Dictionary...") { openWindow(id: "dictionary"); NSApp.activate() }
        Button("Settings...") { openWindow(id: "settings"); NSApp.activate() }
        if case .needsSetup = state.phase {
            Button("Setup...") { openWindow(id: "onboarding"); NSApp.activate() }
        }
        Divider()
        Button("Quit Flusso") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
