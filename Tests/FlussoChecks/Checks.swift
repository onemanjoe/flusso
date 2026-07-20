import Foundation
import FlussoCore

@main
struct Checks {
    static func main() async {
        await Harness.check("Paths creates app support dir") {
            let dir = Paths.appSupportDir()
            try Harness.expect(FileManager.default.fileExists(atPath: dir.path), "dir missing")
            try Harness.expect(dir.lastPathComponent == "Flusso", "wrong dir name")
        }
        await appSettingsChecks()
        await personalDictionaryChecks()
        await historyStoreChecks()
        await ollamaClientChecks()
        await cleanerChecks()
        await fnStateMachineChecks()
        await audioLevelChecks()
        await historyDisplayChecks()
        Harness.finish()
    }
}
