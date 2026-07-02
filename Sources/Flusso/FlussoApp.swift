import SwiftUI

@main
struct FlussoApp: App {
    var body: some Scene {
        MenuBarExtra("Flusso", systemImage: "waveform") {
            Text("Flusso, private local dictation")
            Divider()
            Button("Quit Flusso") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
