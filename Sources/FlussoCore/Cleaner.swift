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

    private static let fillerWords: Set<String> = [
        "ehm", "uhm", "uh", "um", "erm", "mmm", "cioè", "anzi", "aspetta",
        "actually", "tipo", "boh", "insomma", "diciamo",
    ]
    private static let fillerPhrases = ["no wait", "i mean", "scratch that", "voglio dire"]

    /// Text qualifies for the fast path (skip the model entirely) when it is
    /// short, has no filler/self-correction marker, and has no immediate
    /// duplicate word, since Parakeet already punctuates and capitalizes, so
    /// there is nothing left for the model to fix beyond dictionary spelling.
    private static func qualifiesForFastPath(_ text: String) -> Bool {
        let tokens = text.split(whereSeparator: { $0.isWhitespace })
            .map { $0.lowercased().trimmingCharacters(in: CharacterSet.alphanumerics.inverted) }
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty, tokens.count < 12 else { return false }
        if tokens.contains(where: { fillerWords.contains($0) }) { return false }
        for i in 1..<tokens.count where tokens[i] == tokens[i - 1] { return false }
        let normalized = tokens.joined(separator: " ")
        if fillerPhrases.contains(where: { normalized.contains($0) }) { return false }
        return true
    }

    /// Replaces case-insensitive whole-word occurrences of each dictionary term
    /// with the term's exact, canonical spelling. Guarantees personal-term
    /// spelling even on the fast path (no model involved) and as a safety net
    /// after the model reply (in case it misses a term).
    public static func enforceDictionary(_ text: String, terms: [String]) -> String {
        var result = text
        for term in terms {
            let trimmedTerm = term.trimmingCharacters(in: .whitespaces)
            guard !trimmedTerm.isEmpty else { continue }
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: trimmedTerm) + "\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let template = NSRegularExpression.escapedTemplate(for: trimmedTerm)
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: template)
        }
        return result
    }

    public func clean(raw: String, dictionaryTerms: [String]) async -> CleanResult {
        let trimmedRaw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRaw.isEmpty else { return CleanResult(text: "", usedFallback: false) }
        if Self.qualifiesForFastPath(trimmedRaw) {
            return CleanResult(text: Self.enforceDictionary(trimmedRaw, terms: dictionaryTerms), usedFallback: false)
        }
        do {
            let reply = try await chat(Self.systemPrompt(dictionaryTerms: dictionaryTerms), trimmedRaw)
            let cleaned = reply.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return CleanResult(text: trimmedRaw, usedFallback: true) }
            return CleanResult(text: Self.enforceDictionary(cleaned, terms: dictionaryTerms), usedFallback: false)
        } catch {
            return CleanResult(text: Self.enforceDictionary(trimmedRaw, terms: dictionaryTerms), usedFallback: true)
        }
    }
}
