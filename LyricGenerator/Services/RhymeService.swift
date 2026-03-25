import Foundation

actor RhymeService {
    static let shared = RhymeService()

    private var rhymeCache: [String: [RhymeWord]] = [:]
    private var nearRhymeCache: [String: [RhymeWord]] = [:]
    private let session: URLSession

    struct RhymeWord: Codable {
        let word: String
        let score: Int?
        let numSyllables: Int?
    }

    private struct DatamuseResult: Codable {
        let word: String
        let score: Int?
        let numSyllables: Int?
    }

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        self.session = URLSession(configuration: config)
    }

    /// Fetch perfect rhymes from Datamuse API
    func fetchRhymes(for word: String) async -> [RhymeWord] {
        let key = word.lowercased()
        if let cached = rhymeCache[key] { return cached }
        guard !key.isEmpty else { return [] }

        do {
            let urlStr = "https://api.datamuse.com/words?rel_rhy=\(key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key)&max=50&md=s"
            guard let url = URL(string: urlStr) else { return [] }
            let (data, _) = try await session.data(from: url)
            let results = try JSONDecoder().decode([DatamuseResult].self, from: data)
            let words = results.map { RhymeWord(word: $0.word, score: $0.score, numSyllables: $0.numSyllables) }
            rhymeCache[key] = words
            return words
        } catch {
            return []
        }
    }

    /// Fetch near/approximate rhymes from Datamuse API
    func fetchNearRhymes(for word: String) async -> [RhymeWord] {
        let key = word.lowercased()
        if let cached = nearRhymeCache[key] { return cached }
        guard !key.isEmpty else { return [] }

        do {
            let urlStr = "https://api.datamuse.com/words?rel_nry=\(key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key)&max=50&md=s"
            guard let url = URL(string: urlStr) else { return [] }
            let (data, _) = try await session.data(from: url)
            let results = try JSONDecoder().decode([DatamuseResult].self, from: data)
            let words = results.map { RhymeWord(word: $0.word, score: $0.score, numSyllables: $0.numSyllables) }
            nearRhymeCache[key] = words
            return words
        } catch {
            return []
        }
    }

    /// Check if two words rhyme at the given sensitivity level
    /// sensitivity: 0.0 = very loose, 0.5 = moderate, 1.0 = strict
    func doWordsRhyme(_ word1: String, _ word2: String, sensitivity: Double) async -> Bool {
        let w1 = word1.lowercased()
        let w2 = word2.lowercased()
        if w1 == w2 { return true }
        if w1.isEmpty || w2.isEmpty { return false }

        // Perfect rhyme check (always valid at any sensitivity)
        let rhymes = await fetchRhymes(for: w1)
        if rhymes.contains(where: { $0.word == w2 }) { return true }
        let rhymes2 = await fetchRhymes(for: w2)
        if rhymes2.contains(where: { $0.word == w1 }) { return true }

        // Strict mode: only perfect rhymes
        if sensitivity >= 0.85 {
            return false
        }

        // Medium mode: also allow 3+ char ending match
        if sensitivity >= 0.4 {
            if w1.count >= 3 && w2.count >= 3 && w1.suffix(3) == w2.suffix(3) {
                return true
            }
            return false
        }

        // Loose mode: 2-char ending match + near rhymes
        if w1.count >= 2 && w2.count >= 2 && w1.suffix(2) == w2.suffix(2) {
            return true
        }

        // Check near rhymes from Datamuse
        let nearRhymes = await fetchNearRhymes(for: w1)
        if nearRhymes.contains(where: { $0.word == w2 }) { return true }
        let nearRhymes2 = await fetchNearRhymes(for: w2)
        if nearRhymes2.contains(where: { $0.word == w1 }) { return true }

        return false
    }

    /// Assign rhyme scheme labels (A, B, C...) to a set of lines
    func assignScheme(to lines: [LyricLine], sensitivity: Double) async -> [String?] {
        var labels: [String?] = []
        var groups: [(letter: String, indices: [Int])] = []
        var nextLetter = 0

        for (i, line) in lines.enumerated() {
            let word = line.endWord
            guard !word.isEmpty else {
                labels.append(nil)
                continue
            }

            var foundGroup: Int? = nil
            for (gi, group) in groups.enumerated() {
                let representative = lines[group.indices[0]].endWord
                if await doWordsRhyme(word, representative, sensitivity: sensitivity) {
                    foundGroup = gi
                    break
                }
            }

            if let gi = foundGroup {
                groups[gi].indices.append(i)
                labels.append(groups[gi].letter)
            } else {
                let letter = String(UnicodeScalar(65 + nextLetter)!)
                nextLetter += 1
                groups.append((letter: letter, indices: [i]))
                labels.append(letter)
            }
        }

        return labels
    }

    /// Predict what rhyme label the next line should have based on detected pattern
    func predictNextLabel(from labels: [String?]) -> String? {
        let clean = labels.compactMap { $0 }
        guard clean.count >= 2 else { return nil }
        let str = clean.joined()

        // Try repeating pattern detection (ABAB, AABB, ABBA, etc.)
        for patLen in 2...min(4, str.count) {
            let pattern = String(str.prefix(patLen))
            var matches = true
            for (i, ch) in str.enumerated() {
                if ch != pattern[pattern.index(pattern.startIndex, offsetBy: i % patLen)] {
                    matches = false
                    break
                }
            }
            if matches {
                let nextIdx = str.count % patLen
                return String(pattern[pattern.index(pattern.startIndex, offsetBy: nextIdx)])
            }
        }

        // Check if last label appeared only once (needs a pair - AABB style)
        if let last = clean.last {
            let count = clean.filter { $0 == last }.count
            if count == 1 { return last }
        }

        return nil
    }

    /// Fetch sounds-like words from Datamuse API (very loose matches)
    func fetchSoundsLike(for word: String) async -> [RhymeWord] {
        let key = word.lowercased()
        let cacheKey = "sl_\(key)"
        if let cached = nearRhymeCache[cacheKey] { return cached }
        guard !key.isEmpty else { return [] }

        do {
            let urlStr = "https://api.datamuse.com/words?sl=\(key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key)&max=30&md=s"
            guard let url = URL(string: urlStr) else { return [] }
            let (data, _) = try await session.data(from: url)
            let results = try JSONDecoder().decode([DatamuseResult].self, from: data)
            let words = results.map { RhymeWord(word: $0.word, score: $0.score, numSyllables: $0.numSyllables) }
            nearRhymeCache[cacheKey] = words
            return words
        } catch {
            return []
        }
    }

    /// Get rhyme suggestions filtered by sensitivity and syllable count
    /// Strict: only top perfect rhymes. Loose: perfect + near + sounds-like.
    func getSuggestions(for targetWord: String, targetSyllables: Int?, sensitivity: Double) async -> [RhymeWord] {
        var allRhymes = await fetchRhymes(for: targetWord)

        // At strict sensitivity, keep only high-score perfect rhymes
        if sensitivity >= 0.85 {
            let minScore = allRhymes.compactMap { $0.score }.sorted().dropFirst(allRhymes.count / 3).first ?? 0
            allRhymes = allRhymes.filter { ($0.score ?? 0) >= minScore }
        }

        // At moderate or lower, add near rhymes
        if sensitivity < 0.6 {
            let nearRhymes = await fetchNearRhymes(for: targetWord)
            let existingWords = Set(allRhymes.map { $0.word })
            let newNear = nearRhymes.filter { !existingWords.contains($0.word) }
            allRhymes.append(contentsOf: newNear)
        }

        // At very loose, also add sounds-like words
        if sensitivity < 0.3 {
            let soundsLike = await fetchSoundsLike(for: targetWord)
            let existingWords = Set(allRhymes.map { $0.word })
            let newSounds = soundsLike.filter { !existingWords.contains($0.word) }
            allRhymes.append(contentsOf: newSounds)
        }

        guard let target = targetSyllables, target > 0 else { return allRhymes }

        return allRhymes.sorted { a, b in
            let aDiff = abs((a.numSyllables ?? SyllableCounter.countWord(a.word)) - target)
            let bDiff = abs((b.numSyllables ?? SyllableCounter.countWord(b.word)) - target)
            if aDiff != bDiff { return aDiff < bDiff }
            return (a.score ?? 0) > (b.score ?? 0)
        }
    }
}
