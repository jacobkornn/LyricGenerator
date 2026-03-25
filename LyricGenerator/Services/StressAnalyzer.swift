import Foundation

/// Analyzes syllable stress patterns in text for flow/rhythm visualization
/// Uses a heuristic approach based on English stress rules
enum StressAnalyzer {
    // 1 = stressed, 0 = unstressed
    // Common word stress patterns (word -> stress pattern)
    private static let knownPatterns: [String: [Int]] = [
        // 1-syllable stressed words (content words)
        "love": [1], "hate": [1], "light": [1], "dark": [1], "fire": [1, 0],
        "night": [1], "day": [1], "soul": [1], "heart": [1], "mind": [1],
        "dream": [1], "life": [1], "death": [1], "hope": [1], "fear": [1],
        "pain": [1], "rain": [1], "sun": [1], "moon": [1], "star": [1],
        "blood": [1], "bone": [1], "stone": [1], "home": [1], "road": [1],
        "world": [1], "man": [1], "god": [1], "time": [1], "war": [1],
        "peace": [1], "truth": [1], "lie": [1], "cry": [1], "fly": [1],
        "sky": [1], "eye": [1], "hand": [1], "land": [1], "stand": [1],

        // 1-syllable unstressed (function words)
        "the": [0], "a": [0], "an": [0], "and": [0], "or": [0], "but": [0],
        "in": [0], "on": [0], "at": [0], "to": [0], "of": [0], "for": [0],
        "with": [0], "by": [0], "from": [0], "up": [0], "as": [0],
        "is": [0], "am": [0], "are": [0], "was": [0], "were": [0],
        "be": [0], "been": [0], "has": [0], "have": [0], "had": [0],
        "do": [0], "does": [0], "did": [0], "can": [0], "could": [0],
        "will": [0], "would": [0], "shall": [0], "should": [0],
        "may": [0], "might": [0], "must": [0],
        "i": [1], "my": [0], "me": [0], "we": [0], "us": [0], "our": [0],
        "you": [0], "your": [0], "he": [0], "she": [0], "it": [0],
        "his": [0], "her": [0], "its": [0], "they": [0], "them": [0], "their": [0],
        "this": [0], "that": [0], "these": [0], "those": [0],
        "not": [1], "no": [1], "so": [0], "if": [0], "then": [0],

        // 2-syllable words
        "about": [0, 1], "above": [0, 1], "after": [1, 0], "again": [0, 1],
        "away": [0, 1], "before": [0, 1], "begin": [0, 1], "behind": [0, 1],
        "below": [0, 1], "between": [0, 1], "beyond": [0, 1],
        "broken": [1, 0], "burning": [1, 0], "calling": [1, 0],
        "coming": [1, 0], "dancing": [1, 0], "darkness": [1, 0],
        "deeper": [1, 0], "dreaming": [1, 0], "dying": [1, 0],
        "falling": [1, 0], "feeling": [1, 0], "fighting": [1, 0],
        "flying": [1, 0], "forever": [0, 1, 0], "golden": [1, 0],
        "heaven": [1, 0], "holding": [1, 0], "hoping": [1, 0],
        "inside": [0, 1], "into": [1, 0], "knowing": [1, 0],
        "letting": [1, 0], "living": [1, 0], "losing": [1, 0],
        "loving": [1, 0], "maybe": [1, 0], "morning": [1, 0],
        "music": [1, 0], "never": [1, 0], "nothing": [1, 0],
        "only": [1, 0], "open": [1, 0], "over": [1, 0],
        "people": [1, 0], "power": [1, 0], "running": [1, 0],
        "saying": [1, 0], "shadow": [1, 0], "shining": [1, 0],
        "silence": [1, 0], "singing": [1, 0], "sleeping": [1, 0],
        "slowly": [1, 0], "something": [1, 0], "standing": [1, 0],
        "tonight": [0, 1], "under": [1, 0], "waiting": [1, 0],
        "walking": [1, 0], "water": [1, 0], "without": [0, 1],
        "wonder": [1, 0],

        // 3-syllable words
        "another": [0, 1, 0], "beautiful": [1, 0, 0, 0], "beginning": [0, 1, 0],
        "believing": [0, 1, 0], "together": [0, 1, 0], "tomorrow": [0, 1, 0],
        "remember": [0, 1, 0], "surrender": [0, 1, 0], "whatever": [0, 1, 0],
        "yesterday": [1, 0, 0], "everything": [1, 0, 0], "understand": [0, 0, 1],
        "emotion": [0, 1, 0], "pretending": [0, 1, 0],
        "imagine": [0, 1, 0], "illusion": [0, 1, 0],
    ]

    /// Analyze the stress pattern for a full line of text
    static func analyzeStress(_ text: String) -> [Int] {
        let words = text.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { $0.filter { $0.isLetter || $0 == "'" } }
            .filter { !$0.isEmpty }

        var pattern: [Int] = []
        for word in words {
            pattern.append(contentsOf: stressForWord(word))
        }
        return pattern
    }

    /// Get stress pattern for a single word
    static func stressForWord(_ word: String) -> [Int] {
        let w = word.lowercased()
        if let known = knownPatterns[w] { return known }
        return heuristicStress(w)
    }

    /// Heuristic stress assignment based on English rules
    private static func heuristicStress(_ word: String) -> [Int] {
        let syllableCount = SyllableCounter.countWord(word)
        guard syllableCount > 0 else { return [] }
        if syllableCount == 1 { return [1] } // Default single-syllable to stressed

        // Common suffixes that attract or repel stress
        let stressedSuffixes = ["tion", "sion", "ment", "ness", "ful", "ous", "ive", "ence", "ance"]
        let unstressedSuffixes = ["ing", "ed", "er", "est", "ly", "en", "ble", "al", "ure"]

        var pattern = Array(repeating: 0, count: syllableCount)

        // Default: stress on first syllable (most common in English)
        pattern[0] = 1

        // Check for prefixes that shift stress
        let prefixes = ["un", "re", "de", "pre", "dis", "mis", "out", "over", "under", "be", "a"]
        for prefix in prefixes {
            if word.hasPrefix(prefix) && word.count > prefix.count + 2 {
                pattern[0] = 0
                if pattern.count > 1 { pattern[1] = 1 }
                break
            }
        }

        // Check for stress-attracting suffixes (stress on penultimate)
        for suffix in stressedSuffixes {
            if word.hasSuffix(suffix) && syllableCount >= 2 {
                pattern = Array(repeating: 0, count: syllableCount)
                pattern[max(0, syllableCount - 2)] = 1
                break
            }
        }

        // Check for unstressed suffixes
        for suffix in unstressedSuffixes {
            if word.hasSuffix(suffix) && syllableCount >= 2 {
                pattern[syllableCount - 1] = 0
                if pattern.allSatisfy({ $0 == 0 }) { pattern[0] = 1 }
                break
            }
        }

        return pattern
    }

    /// Compare two stress patterns for similarity (0.0 = no match, 1.0 = perfect)
    static func similarity(_ a: [Int], _ b: [Int]) -> Double {
        guard !a.isEmpty && !b.isEmpty else { return 0.0 }
        let len = min(a.count, b.count)
        var matches = 0
        for i in 0..<len {
            if a[i] == b[i] { matches += 1 }
        }
        let lengthPenalty = 1.0 - (Double(abs(a.count - b.count)) / Double(max(a.count, b.count)))
        return (Double(matches) / Double(len)) * lengthPenalty
    }

    /// Get a human-readable representation of the stress pattern
    /// Uses "DA" for stressed and "da" for unstressed (like iambic notation)
    static func patternString(_ pattern: [Int]) -> String {
        pattern.map { $0 == 1 ? "DA" : "da" }.joined(separator: " ")
    }
}
