import Cocoa

@MainActor
enum Injector {
    private static var generation = 0
    private static var pendingSaved: [NSPasteboardItem]?

    static func paste(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Reuse the pending snapshot when a restore is still scheduled, so rapid
        // consecutive pastes restore the user's true original clipboard.
        let saved = pendingSaved ?? snapshot(of: pasteboard)
        pendingSaved = saved
        generation += 1
        let expected = generation

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            guard generation == expected else { return }
            pendingSaved = nil
            guard !saved.isEmpty else { return }
            pasteboard.clearContents()
            pasteboard.writeObjects(saved)
        }
    }

    private static func snapshot(of pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }
}
