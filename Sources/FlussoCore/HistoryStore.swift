import Foundation

public struct DictationRecord: Codable, Equatable {
    public let date: Date
    public let raw: String
    public let cleaned: String
    public let audioFile: String?

    public init(date: Date, raw: String, cleaned: String, audioFile: String?) {
        self.date = date
        self.raw = raw
        self.cleaned = cleaned
        self.audioFile = audioFile
    }
}

public final class HistoryStore {
    private let corpusURL: URL
    public let audioDir: URL
    private let lock = NSLock()

    public init(directory: URL) {
        corpusURL = directory.appendingPathComponent("corpus.jsonl")
        audioDir = directory.appendingPathComponent("audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
    }

    public func append(_ record: DictationRecord) throws {
        lock.lock()
        defer { lock.unlock() }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        var line = try enc.encode(record)
        line.append(0x0A)
        guard FileManager.default.fileExists(atPath: corpusURL.path) else {
            try line.write(to: corpusURL)
            return
        }
        let handle = try FileHandle(forWritingTo: corpusURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }

    private func allRecords() -> [DictationRecord] {
        lock.lock()
        defer { lock.unlock() }
        guard let text = try? String(contentsOf: corpusURL, encoding: .utf8) else { return [] }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return text.split(separator: "\n").compactMap {
            try? dec.decode(DictationRecord.self, from: Data($0.utf8))
        }
    }

    public var count: Int { allRecords().count }

    public func recent(_ n: Int) -> [DictationRecord] {
        Array(allRecords().suffix(n).reversed())
    }

    public func deleteAll() throws {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: corpusURL)
        try? FileManager.default.removeItem(at: audioDir)
        try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
    }
}
