import Foundation

struct CheckError: Error, CustomStringConvertible {
    let description: String
    init(_ d: String) { description = d }
}

enum Harness {
    static var passed = 0
    static var failed = 0

    static func check(_ name: String, _ body: () async throws -> Void) async {
        do { try await body(); passed += 1; print("PASS \(name)") }
        catch { failed += 1; print("FAIL \(name): \(error)") }
    }

    static func expect(_ cond: Bool, _ msg: String = "expectation failed") throws {
        if !cond { throw CheckError(msg) }
    }

    static func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("flusso-checks-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func finish() -> Never {
        print("\(passed) passed, \(failed) failed")
        exit(failed == 0 ? 0 : 1)
    }
}
