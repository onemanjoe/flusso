import Foundation

public struct AppSettings: Codable, Equatable {
    public var cleanupEnabled: Bool = true
    public var ollamaEndpoint: String = "http://localhost:11434"
    public var ollamaModel: String = "qwen2.5:7b"
    public var storeAudio: Bool = true
    public var launchAtLogin: Bool = false
    public var paused: Bool = false

    public init() {}

    static func fileURL(in dir: URL) -> URL { dir.appendingPathComponent("settings.json") }

    public static func load(from dir: URL) -> AppSettings {
        guard let data = try? Data(contentsOf: fileURL(in: dir)),
              let s = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return s
    }

    public func save(to dir: URL) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(self).write(to: Self.fileURL(in: dir), options: .atomic)
    }
}
