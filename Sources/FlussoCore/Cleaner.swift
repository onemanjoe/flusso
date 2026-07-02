import Foundation

public typealias ChatFunction = (_ system: String, _ user: String) async throws -> String

public struct CleanResult: Equatable {
    public let text: String
    public let usedFallback: Bool

    public init(text: String, usedFallback: Bool) {
        self.text = text
        self.usedFallback = usedFallback
    }
}

public struct Cleaner {
    private let chat: ChatFunction

    public init(chat: @escaping ChatFunction) {
        self.chat = chat
    }

    public static func systemPrompt(dictionaryTerms: [String]) -> String {
        var prompt = """
        You are a dictation cleanup engine. You receive one raw speech-to-text transcript. \
        Reply with ONLY the cleaned text, no comments, no quotes, no explanations.
        Rules:
        1. Keep the language of the transcript. Italian stays Italian, English stays English, \
        mixed stays mixed. Never translate.
        2. Remove filler words and hesitations, for example: uh, um, ehm, and repeated words.
        3. Fix punctuation, capitalization, and obvious transcription mistakes. \
        Do not change the meaning or the wording style.
        4. When the speaker corrects themselves, keep only the final intended version \
        and drop the abandoned words.
        5. Never answer the content, never add information, never summarize.
        """
        if !dictionaryTerms.isEmpty {
            prompt += "\n6. Personal terms, always spell them exactly as written here: "
                + dictionaryTerms.joined(separator: ", ") + "."
        }
        return prompt
    }

    public func clean(raw: String, dictionaryTerms: [String]) async -> CleanResult {
        let trimmedRaw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRaw.isEmpty else { return CleanResult(text: "", usedFallback: false) }
        do {
            let reply = try await chat(Self.systemPrompt(dictionaryTerms: dictionaryTerms), trimmedRaw)
            let cleaned = reply.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return CleanResult(text: trimmedRaw, usedFallback: true) }
            return CleanResult(text: cleaned, usedFallback: false)
        } catch {
            return CleanResult(text: trimmedRaw, usedFallback: true)
        }
    }
}
