import Foundation

protocol TranscriptionEngine: AnyObject {
    var displayName: String { get }
    var isReady: Bool { get }
    func prepare() async throws
    func transcribe(_ samples: [Float]) async throws -> String
}
