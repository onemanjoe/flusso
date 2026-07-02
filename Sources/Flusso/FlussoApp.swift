import SwiftUI

@main
struct FlussoMain {
    static func main() {
        // Adaptation (task-12, see task-12-report.md): the entry point used to be
        // `static func main() async`, awaiting `SelfTest.runIfRequested()` before
        // calling the synchronous `FlussoApp.main()`. Verified empirically that
        // this breaks Swift Concurrency once AppKit's run loop takes over inside
        // `FlussoApp.main()`: no `Task {}`, `.task {}`, or even a plain
        // `DispatchQueue.main.asyncAfter` ever fires again, anywhere in the app,
        // for the rest of the process's life. That silently kills the entire
        // dictation pipeline (`Task { await process(samples) }` never runs).
        // Fix: keep `main()` synchronous so AppKit owns the real main thread and
        // run loop from the start, and bridge the async CLI selftests onto that
        // same run loop instead of Swift's async-main machinery.
        guard SelfTest.isRequested else {
            FlussoApp.main()
            return
        }
        Task {
            _ = await SelfTest.runIfRequested()
            exit(0)
        }
        RunLoop.main.run()
    }
}

struct FlussoApp: App {
    @StateObject private var state = AppState()

    init() {
        // Adaptation (task-12): `.task` on MenuBarExtra content never fires from
        // a plain launch (verified empirically), only once the menu is opened,
        // which could be never. Start engines from `init()` instead so dictation
        // works without the user having to click the menu bar icon first.
        // `startEngines()` guards against reentry, so if `.task` below also
        // fires later (e.g. once the menu is opened), it is a safe no-op.
        let state = self.state
        Task { await state.startEngines() }
    }

    var menuIcon: String {
        switch state.phase {
        case .recording: return "waveform.badge.mic"
        case .processing: return "waveform.badge.magnifyingglass"
        case .needsSetup: return "waveform.slash"
        default: return "waveform"
        }
    }

    var body: some Scene {
        MenuBarExtra("Flusso", systemImage: menuIcon) {
            MenuContent(state: state)
                .task {
                    await state.startEngines()
                }
        }
        // Window scenes for Task 13; placeholders keep openWindow ids valid.
        Window("Recent Dictations", id: "history") { Text("Coming in Task 13").padding() }
        Window("Personal Dictionary", id: "dictionary") { Text("Coming in Task 13").padding() }
        Window("Flusso Settings", id: "settings") { Text("Coming in Task 13").padding() }
        Window("Flusso Setup", id: "onboarding") { Text("Coming in Task 14").padding() }
    }
}
