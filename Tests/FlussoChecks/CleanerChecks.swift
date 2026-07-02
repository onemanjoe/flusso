import Foundation
import FlussoCore

func cleanerChecks() async {
    await Harness.check("system prompt embeds dictionary and language rule") {
        let p = Cleaner.systemPrompt(dictionaryTerms: ["Materik", "Klaviyo"])
        try Harness.expect(p.contains("Materik, Klaviyo"), "terms not embedded")
        try Harness.expect(p.lowercased().contains("never translate"), "language rule missing")
        try Harness.expect(!p.contains("\u{2014}") && !p.contains("\u{2013}"), "prompt contains a dash")
    }
    await Harness.check("clean uses model reply") {
        let c = Cleaner(chat: { _, user in
            try Harness.expect(user.contains("ehm ciao"), "raw not passed")
            return "  Ciao.  "
        })
        let r = await c.clean(raw: "ehm ciao", dictionaryTerms: [])
        try Harness.expect(r == CleanResult(text: "Ciao.", usedFallback: false), "got \(r)")
    }
    await Harness.check("clean falls back to raw on error") {
        let c = Cleaner(chat: { _, _ in throw OllamaError.timeout })
        let r = await c.clean(raw: "testo grezzo", dictionaryTerms: [])
        try Harness.expect(r == CleanResult(text: "testo grezzo", usedFallback: true), "got \(r)")
    }
    await Harness.check("clean falls back on empty reply") {
        let c = Cleaner(chat: { _, _ in "   " })
        let r = await c.clean(raw: "qualcosa", dictionaryTerms: [])
        try Harness.expect(r == CleanResult(text: "qualcosa", usedFallback: true), "got \(r)")
    }
    await Harness.check("clean skips empty raw without calling model") {
        let c = Cleaner(chat: { _, _ in
            try Harness.expect(false, "model called for empty raw")
            return ""
        })
        let r = await c.clean(raw: "   ", dictionaryTerms: [])
        try Harness.expect(r == CleanResult(text: "", usedFallback: false), "got \(r)")
    }
}
