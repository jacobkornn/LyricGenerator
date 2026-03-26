import Foundation

struct LyricEntry: Identifiable, Codable {
    let id: UUID
    var title: String
    var customTitle: String
    var lines: [LyricLine]
    var wordBank: [String]
    var sections: [SectionMarker]
    var mode: EntryMode
    var poemForm: PoemForm?
    var createdAt: Date
    var updatedAt: Date

    var displayTitle: String {
        let trimmed = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return title
    }

    init(lines: [LyricLine] = [], wordBank: [String] = [], customTitle: String = "", sections: [SectionMarker] = [], mode: EntryMode = .lyrics, poemForm: PoemForm? = nil) {
        self.id = UUID()
        self.lines = lines
        self.wordBank = wordBank
        self.sections = sections
        self.mode = mode
        self.poemForm = poemForm
        self.customTitle = customTitle
        self.createdAt = Date()
        self.updatedAt = Date()
        self.title = lines.first(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty })?.text
            .trimmingCharacters(in: .whitespaces)
            .prefix(50)
            .description ?? "Untitled"
    }

    // Handle decoding from older data that lacks new fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        customTitle = try container.decodeIfPresent(String.self, forKey: .customTitle) ?? ""
        lines = try container.decode([LyricLine].self, forKey: .lines)
        wordBank = try container.decodeIfPresent([String].self, forKey: .wordBank) ?? []
        sections = try container.decodeIfPresent([SectionMarker].self, forKey: .sections) ?? []
        mode = try container.decodeIfPresent(EntryMode.self, forKey: .mode) ?? .lyrics
        poemForm = try container.decodeIfPresent(PoemForm.self, forKey: .poemForm)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    mutating func refreshTitle() {
        title = lines.first(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty })?.text
            .trimmingCharacters(in: .whitespaces)
            .prefix(50)
            .description ?? "Untitled"
        updatedAt = Date()
    }

    /// Get the structure summary like "V1 → C → V2 → Br → C"
    var structureSummary: String {
        sections.map { $0.type.shortLabel + (($0.number != nil) ? "\($0.number!)" : "") }.joined(separator: " → ")
    }
}
