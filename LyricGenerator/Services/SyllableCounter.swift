import Foundation
import NaturalLanguage

enum SyllableCounter {
    /// Count syllables in a full line of text
    static func count(_ text: String) -> Int {
        let words = text.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { $0.filter { $0.isLetter || $0 == "'" } }
            .filter { !$0.isEmpty }

        return words.reduce(0) { $0 + countWord($1) }
    }

    /// Count syllables in a single word using vowel-group heuristic
    static func countWord(_ word: String) -> Int {
        let w = word.lowercased()
        guard !w.isEmpty else { return 0 }

        // Common known words for accuracy
        let known: [String: Int] = [
            "the": 1, "a": 1, "an": 1, "i": 1, "my": 1, "your": 1,
            "every": 3, "everything": 4, "beautiful": 4, "comfortable": 4,
            "fire": 2, "desire": 3, "higher": 2, "power": 2, "flower": 2,
            "hour": 1, "our": 1, "their": 1, "there": 1, "where": 1,
            "people": 2, "little": 2, "middle": 2, "simple": 2,
            "real": 1, "feel": 1, "deal": 1, "steal": 1,
            "create": 2, "erate": 2, "ire": 2, "ore": 1,
        ]
        if let k = known[w] { return k }

        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        var count = 0
        var prevVowel = false
        let chars = Array(w)

        for (i, ch) in chars.enumerated() {
            let isVowel = vowels.contains(ch)
            if isVowel && !prevVowel {
                count += 1
            }
            prevVowel = isVowel

            // Handle silent e at end
            if i == chars.count - 1 && ch == "e" && count > 1 {
                // Check if it's not a standalone vowel group
                if i > 0 && !vowels.contains(chars[i - 1]) {
                    count -= 1
                }
            }
        }

        // Words like "le" at end (e.g., "bottle") add a syllable
        if w.hasSuffix("le") && w.count > 2 {
            let beforeLe = chars[chars.count - 3]
            if !vowels.contains(beforeLe) && count == 0 {
                count = 1
            }
        }

        // -ed ending usually doesn't add a syllable unless preceded by t or d
        if w.hasSuffix("ed") && w.count > 3 {
            let beforeEd = chars[chars.count - 3]
            if beforeEd != "t" && beforeEd != "d" {
                // The "ed" was likely counted as a syllable, subtract it
                // Only if we haven't already handled it
            }
        }

        return max(count, 1)
    }
}
