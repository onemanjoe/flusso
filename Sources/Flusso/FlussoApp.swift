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
    @StateObject private var state: AppState

    init() {
        // Adaptation (task-12): `.task` on MenuBarExtra content never fires from
        // a plain launch (verified empirically), only once the menu is opened,
        // which could be never. Start engines from `init()` instead so dictation
        // works without the user having to click the menu bar icon first.
        // `startEngines()` guards against reentry.
        //
        // Post-review fix (C1): reading `self.state` inside `init()` before
        // `_state` is assigned would read a transient `AppState` distinct from
        // the one actually installed in the view graph by `@StateObject`,
        // since SwiftUI creates its own storage for the property wrapper on
        // first materialization. Build the instance explicitly and install it
        // via `_state = StateObject(wrappedValue:)` so the Task below and the
        // graph share the exact same object.
        let state = AppState()
        _state = StateObject(wrappedValue: state)
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
        }
        // Window scenes for Task 13; placeholders keep openWindow ids valid.
        Window("Recent Dictations", id: "history") { Text("Coming in Task 13").padding() }
        Window("Personal Dictionary", id: "dictionary") { Text("Coming in Task 13").padding() }
        Window("Flusso Settings", id: "settings") { Text("Coming in Task 13").padding() }
        Window("Flusso Setup", id: "onboarding") { Text("Coming in Task 14").padding() }
    }
}
