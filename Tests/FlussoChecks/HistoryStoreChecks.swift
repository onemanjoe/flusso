import Foundation
import FlussoCore

func historyStoreChecks() async {
    await Harness.check("history append and recent, newest first") {
        let store = HistoryStore(directory: Harness.tempDir())
        for i in 1...25 {
            try store.append(DictationRecord(date: Date(timeIntervalSince1970: Double(i)),
                                             raw: "raw \(i)", cleaned: "clean \(i)", audioFile: nil))
        }
        let recent = store.recent(20)
        try Harness.expect(recent.count == 20, "expected 20, got \(recent.count)")
        try Harness.expect(recent.first?.cleaned == "clean 25", "not newest first")
        try Harness.expect(store.count == 25, "corpus count wrong")
    }
    await Harness.check("history survives reopen") {
        let dir = Harness.tempDir()
        try HistoryStore(directory: dir)
            .append(DictationRecord(date: Date(), raw: "a", cleaned: "b", audioFile: nil))
        try Harness.expect(HistoryStore(directory: dir).count == 1, "not persisted")
    }
    await Harness.check("deleteAll wipes corpus and audio") {
        let dir = Harness.tempDir()
        let store = HistoryStore(directory: dir)
        let wav = store.audioDir.appendingPathComponent("x.wav")
        try Data([1, 2, 3]).write(to: wav)
        try store.append(DictationRecord(date: Date(), raw: "a", cleaned: "b", audioFile: "x.wav"))
        try store.deleteAll()
        try Harness.expect(store.count == 0, "corpus not wiped")
        try Harness.expect(!FileManager.default.fileExists(atPath: wav.path), "audio not wiped")
    }
}
