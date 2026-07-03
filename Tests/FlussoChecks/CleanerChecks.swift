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
        let r = await c.clean(raw: "ehm testo grezzo", dictionaryTerms: [])
        try Harness.expect(r == CleanResult(text: "ehm testo grezzo", usedFallback: true), "got \(r)")
    }
    await Harness.check("clean falls back on empty reply") {
        let c = Cleaner(chat: { _, _ in "   " })
        let r = await c.clean(raw: "ehm qualcosa", dictionaryTerms: [])
        try Harness.expect(r == CleanResult(text: "ehm qualcosa", usedFallback: true), "got \(r)")
    }
    await Harness.check("clean skips empty raw without calling model") {
        let c = Cleaner(chat: { _, _ in
            try Harness.expect(false, "model called for empty raw")
            return ""
        })
        let r = await c.clean(raw: "   ", dictionaryTerms: [])
        try Harness.expect(r == CleanResult(text: "", usedFallback: false), "got \(r)")
    }
    await Harness.check("fast path skips model for short clean text and enforces dictionary") {
        let c = Cleaner(chat: { _, _ in
            try Harness.expect(false, "model called on fast path")
            return ""
        })
        let r = await c.clean(raw: "manda il file a materik domani", dictionaryTerms: ["Materik"])
        try Harness.expect(r == CleanResult(text: "manda il file a Materik domani", usedFallback: false), "got \(r)")
    }
    await Harness.check("marker routes to model") {
        var called = false
        let c = Cleaner(chat: { _, _ in called = true; return "Ciao." })
        _ = await c.clean(raw: "ehm ciao", dictionaryTerms: [])
        try Harness.expect(called, "model not called despite marker")
    }
    await Harness.check("duplicate word routes to model") {
        var called = false
        let c = Cleaner(chat: { _, _ in called = true; return "send the file" })
        _ = await c.clean(raw: "send the the file", dictionaryTerms: [])
        try Harness.expect(called, "model not called despite duplicate")
    }
    await Harness.check("long text routes to model") {
        var called = false
        let c = Cleaner(chat: { _, _ in called = true; return "x" })
        _ = await c.clean(raw: "uno due tre quattro cinque sei sette otto nove dieci undici dodici tredici", dictionaryTerms: [])
        try Harness.expect(called, "model not called despite length")
    }
    await Harness.check("enforceDictionary whole words only, multi-word terms") {
        let out = Cleaner.enforceDictionary("il purecase e trovi technologies, ma non peraltro", terms: ["PureCase", "Trovi Technologies", "Alt"])
        try Harness.expect(out == "il PureCase e Trovi Technologies, ma non peraltro", "got \(out)")
    }
    await Harness.check("model reply gets dictionary enforcement") {
        let c = Cleaner(chat: { _, _ in "Ciao, ehm scrivo a materik." })
        let r = await c.clean(raw: "ehm ciao scrivo a materik", dictionaryTerms: ["Materik"])
        try Harness.expect(r.text.contains("Materik"), "got \(r.text)")
    }
}
