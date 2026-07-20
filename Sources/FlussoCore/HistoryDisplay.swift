import Foundation

/// Pure presentation helpers for showing recent dictations in the notch.
/// In FlussoCore so FlussoChecks can test them.
public enum HistoryDisplay {
    /// Text to show/copy for a record: prefer cleaned, fall back to raw when empty.
    public static func text(cleaned: String, raw: String) -> String {
        let c = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return c.isEmpty ? raw.trimmingCharacters(in: .whitespacesAndNewlines) : c
    }

    /// One-line snippet: collapse whitespace/newlines, truncate to `max` with "...".
    public static func snippet(cleaned: String, raw: String, max: Int = 48) -> String {
        let full = text(cleaned: cleaned, raw: raw)
        let collapsed = full.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
        if collapsed.count <= max { return collapsed }
        return String(collapsed.prefix(Swift.max(0, max - 3))) + "..."
    }

    /// Short relative time: "ora", "N min", "N h", "N g".
    public static func relativeTime(from date: Date, to now: Date) -> String {
        let s = Swift.max(0, now.timeIntervalSince(date))
        switch s {
        case ..<60: return "ora"
        case ..<3600: return "\(Int(s / 60)) min"
        case ..<86_400: return "\(Int(s / 3600)) h"
        default: return "\(Int(s / 86_400)) g"
        }
    }
}
