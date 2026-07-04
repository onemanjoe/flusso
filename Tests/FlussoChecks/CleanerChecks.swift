import Foundation
import FlussoCore

func cleanerChecks() async {
    await Harness.check("system prompt embeds dictionary, names language, forbids translation") {
        let p = Cleaner.systemPrompt(dictionaryTerms: ["Contoso", "Zephyr"], language: "English")
        try Harness.expect(p.contains("Contoso, Zephyr"), "terms not embedded")
        try Harness.expect(p.contains("English"), "language not named in prompt")
        try Harness.expect(p.lowercased().contains("never translate"), "language rule missing")
        try Harness.expect(!p.contains("\u{2014}") && !p.contains("\u{2013}"), "prompt contains a dash")
    }
    await Harness.check("cleaner pins English for an English transcript") {
        var seen = ""
        let c = Cleaner(chat: { sys, _ in seen = sys; return "ok" })
        _ = await c.clean(raw: "please send the updated report to the whole team tomorrow morning without fail",
                          dictionaryTerms: [])
        try Harness.expect(seen.contains("English"), "prompt did not pin English, got: \(seen.prefix(70))")
    }
    await Harness.check("cleaner pins Italian for an Italian transcript") {
        var seen = ""
        let c = Cleaner(chat: { sys, _ in seen = sys; return "ok" })
        _ = await c.clean(raw: "per favore manda il rapporto aggiornato a tutta la squadra domani mattina senza fallo",
                          dictionaryTerms: [])
        try Harness.expect(seen.contains("Italian"), "prompt did not pin Italian, got: \(seen.prefix(70))")
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
        let r = await c.clean(raw: "manda il file a contoso domani", dictionaryTerms: ["Contoso"])
        try Harness.expect(r == CleanResult(text: "manda il file a Contoso domani", usedFallback: false), "got \(r)")
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
        let out = Cleaner.enforceDictionary("il skycase e acme robotics, ma non peraltro", terms: ["SkyCase", "Acme Robotics", "Alt"])
        try Harness.expect(out == "il SkyCase e Acme Robotics, ma non peraltro", "got \(out)")
    }
    await Harness.check("model reply gets dictionary enforcement") {
        let c = Cleaner(chat: { _, _ in "Ciao, ehm scrivo a contoso." })
        let r = await c.clean(raw: "ehm ciao scrivo a contoso", dictionaryTerms: ["Contoso"])
        try Harness.expect(r.text.contains("Contoso"), "got \(r.text)")
    }
    await Harness.check("punctuation-adjacent filler routes to model") {
        var called = false
        let c = Cleaner(chat: { _, _ in called = true; return "Send the file." })
        _ = await c.clean(raw: "Um, send the file.", dictionaryTerms: [])
        try Harness.expect(called, "comma-attached filler must not take the fast path")
    }
    await Harness.check("punctuation-attached duplicate routes to model") {
        var called = false
        let c = Cleaner(chat: { _, _ in called = true; return "send it" })
        _ = await c.clean(raw: "send it it.", dictionaryTerms: [])
        try Harness.expect(called, "trailing-punctuation duplicate must not take the fast path")
    }
}
