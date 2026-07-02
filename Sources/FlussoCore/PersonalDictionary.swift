import Foundation

public struct PersonalDictionary: Codable, Equatable {
    public private(set) var terms: [String]

    public static let seedTerms = [
        "Materik", "Trovi Technologies", "Klaviyo", "PureCase", "CrystalCase",
        "Ripple", "Halo", "Rolando", "Shenzhen",
    ]

    static func fileURL(in dir: URL) -> URL { dir.appendingPathComponent("dictionary.json") }

    public static func load(from dir: URL) -> PersonalDictionary {
        guard let data = try? Data(contentsOf: fileURL(in: dir)),
              let d = try? JSONDecoder().decode(PersonalDictionary.self, from: data)
        else { return PersonalDictionary(terms: seedTerms) }
        return d
    }

    public func save(to dir: URL) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(self).write(to: Self.fileURL(in: dir), options: .atomic)
    }

    @discardableResult
    public mutating func add(_ term: String) -> Bool {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty,
              !terms.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame })
        else { return false }
        terms.append(t)
        return true
    }

    public mutating func remove(_ term: String) {
        terms.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
    }
}
