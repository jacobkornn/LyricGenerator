import Foundation

struct LyricLine: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var rhymeLabel: String?
    var syllableCount: Int
    var endWord: String

    init(text: String = "", rhymeLabel: String? = nil) {
        self.id = UUID()
        self.text = text
        self.rhymeLabel = rhymeLabel
        self.syllableCount = SyllableCounter.count(text)
        self.endWord = LyricLine.extractEndWord(from: text)
    }

    mutating func updateText(_ newText: String) {
        text = newText
        syllableCount = SyllableCounter.count(newText)
        endWord = LyricLine.extractEndWord(from: newText)
    }

    static func extractEndWord(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let last = words.last else { return "" }
        return last.lowercased().filter { $0.isLetter || $0 == "'" || $0 == "-" }
    }
}
