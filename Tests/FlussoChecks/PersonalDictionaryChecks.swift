import Foundation
import FlussoCore

func personalDictionaryChecks() async {
    await Harness.check("dictionary seeds on first load") {
        let d = PersonalDictionary.load(from: Harness.tempDir())
        try Harness.expect(d.terms.contains("Materik"), "missing seed Materik")
        try Harness.expect(d.terms.contains("Klaviyo"), "missing seed Klaviyo")
    }
    await Harness.check("dictionary add trims, dedupes case-insensitively") {
        var d = PersonalDictionary.load(from: Harness.tempDir())
        try Harness.expect(d.add("  Vicenza  "), "add failed")
        try Harness.expect(d.terms.contains("Vicenza"), "not added trimmed")
        try Harness.expect(!d.add("vicenza"), "duplicate accepted")
        try Harness.expect(!d.add("   "), "empty accepted")
    }
    await Harness.check("dictionary remove and round-trip") {
        let dir = Harness.tempDir()
        var d = PersonalDictionary.load(from: dir)
        d.add("Vicenza")
        d.remove("Materik")
        try d.save(to: dir)
        let loaded = PersonalDictionary.load(from: dir)
        try Harness.expect(loaded.terms.contains("Vicenza"), "lost added term")
        try Harness.expect(!loaded.terms.contains("Materik"), "remove not persisted")
    }
}
