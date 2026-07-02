import Foundation

struct DictionaryEntry: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var spoken: String
    var written: String
}

/// Deterministic transcript cleanup: no LLM, no meaning drift, ~zero latency.
struct TextProcessor {
    var removeFillers: Bool
    var dictionary: [DictionaryEntry]

    // Words that legitimately repeat in English ("had had", "no no").
    private static let repeatAllowlist: Set<String> = ["had", "that", "no", "so", "very", "really"]

    func process(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        if removeFillers {
            text = Self.stripFillers(text)
        }
        text = Self.collapseRepeats(text)
        for entry in dictionary where !entry.spoken.isEmpty {
            text = Self.substitute(entry, in: text)
        }
        text = Self.tidy(text)
        return text
    }

    // MARK: - Rules

    /// Remove filler words (um, uh, erm, …) plus any punctuation that trailed them.
    static func stripFillers(_ text: String) -> String {
        let pattern = "(?i)\\b(?:u+m+|u+h+|erm+|ehm+|mhm+|hmm+)\\b[,.]?\\s*"
        var result = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        // A filler at sentence start can leave ", word" or an orphaned comma.
        result = result.replacingOccurrences(of: "^[,.\\s]+", with: "", options: .regularExpression)
        return result
    }

    /// Collapse accidental immediate word repeats ("the the" → "the"),
    /// preserving legitimate doubles via the allowlist.
    static func collapseRepeats(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "\\b(\\p{L}+)(\\s+\\1\\b)+",
            options: [.caseInsensitive]
        ) else { return text }

        let ns = text as NSString
        var result = text
        // Iterate matches back-to-front so ranges stay valid while replacing.
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches.reversed() {
            let word = ns.substring(with: match.range(at: 1))
            if repeatAllowlist.contains(word.lowercased()) { continue }
            let start = result.index(result.startIndex, offsetBy: match.range.location)
            let end = result.index(start, offsetBy: match.range.length)
            result.replaceSubrange(start..<end, with: word)
        }
        return result
    }

    /// Whole-word, case-insensitive replacement of a spoken form with its written form.
    static func substitute(_ entry: DictionaryEntry, in text: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: entry.spoken)
        let pattern = "(?i)\\b\(escaped)\\b"
        return text.replacingOccurrences(
            of: pattern,
            with: entry.written,
            options: .regularExpression
        )
    }

    /// Final whitespace/punctuation tidy + sentence-start capitalization.
    static func tidy(_ text: String) -> String {
        var t = text
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s+([,.!?;:])", with: "$1", options: .regularExpression)
        // Space after commas/semicolons before any letter…
        t = t.replacingOccurrences(of: "([,;:])(?=\\p{L})", with: "$1 ", options: .regularExpression)
        // …but after sentence punctuation only before an uppercase letter,
        // so abbreviations like "p.m." or "e.g." stay intact.
        t = t.replacingOccurrences(of: "([.!?])(?=\\p{Lu})", with: "$1 ", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = t.first, first.isLowercase {
            t = first.uppercased() + t.dropFirst()
        }
        return t
    }
}
