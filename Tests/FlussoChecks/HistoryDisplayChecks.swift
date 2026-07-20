import Foundation
import FlussoCore

func historyDisplayChecks() async {
    await Harness.check("text prefers cleaned, falls back to raw when cleaned empty") {
        try Harness.expect(HistoryDisplay.text(cleaned: "Ciao.", raw: "ehm ciao") == "Ciao.", "cleaned not preferred")
        try Harness.expect(HistoryDisplay.text(cleaned: "   ", raw: "ciao grezzo") == "ciao grezzo", "raw fallback failed")
    }
    await Harness.check("snippet collapses whitespace and newlines to one line") {
        let s = HistoryDisplay.snippet(cleaned: "riga uno\n  riga\tdue", raw: "", max: 48)
        try Harness.expect(s == "riga uno riga due", "got '\(s)'")
    }
    await Harness.check("snippet truncates with ellipsis at max") {
        let s = HistoryDisplay.snippet(cleaned: String(repeating: "a", count: 60), raw: "", max: 10)
        try Harness.expect(s.count == 10, "wrong length \(s.count): '\(s)'")
        try Harness.expect(s.hasSuffix("..."), "no ellipsis: '\(s)'")
    }
    await Harness.check("relativeTime buckets seconds/minutes/hours/days") {
        let now = Date(timeIntervalSince1970: 1_000_000)
        try Harness.expect(HistoryDisplay.relativeTime(from: now.addingTimeInterval(-10), to: now) == "ora", "sec")
        try Harness.expect(HistoryDisplay.relativeTime(from: now.addingTimeInterval(-65), to: now) == "1 min", "min")
        try Harness.expect(HistoryDisplay.relativeTime(from: now.addingTimeInterval(-7200), to: now) == "2 h", "hour")
        try Harness.expect(HistoryDisplay.relativeTime(from: now.addingTimeInterval(-172800), to: now) == "2 g", "day")
    }
}
