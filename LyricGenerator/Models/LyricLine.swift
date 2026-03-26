import Foundation

/// The type of section a line belongs to
enum SectionType: String, Codable, CaseIterable, Equatable {
    case verse = "Verse"
    case chorus = "Chorus"
    case bridge = "Bridge"
    case preChorus = "Pre-Chorus"
    case outro = "Outro"
    case intro = "Intro"
    case hook = "Hook"

    var icon: String {
        switch self {
        case .verse: return "text.alignleft"
        case .chorus: return "music.note"
        case .bridge: return "arrow.left.and.right"
        case .preChorus: return "arrow.up.right"
        case .outro: return "flag.checkered"
        case .intro: return "play"
        case .hook: return "star"
        }
    }

    var shortLabel: String {
        switch self {
        case .verse: return "V"
        case .chorus: return "C"
        case .bridge: return "Br"
        case .preChorus: return "PC"
        case .outro: return "O"
        case .intro: return "I"
        case .hook: return "H"
        }
    }

    /// Mode-aware display name (e.g., "Verse" in lyrics, "Stanza" in poem)
    func displayName(for mode: EntryMode) -> String {
        switch mode {
        case .poem:
            switch self {
            case .verse:    return "Stanza"
            case .chorus:   return "Refrain"
            case .bridge:   return "Volta"
            case .preChorus: return "Turn"
            case .outro:    return "Coda"
            case .intro:    return "Opening"
            case .hook:     return "Refrain"
            }
        default:
            return rawValue
        }
    }
}

/// A section marker that separates groups of lines
struct SectionMarker: Identifiable, Codable, Equatable {
    let id: UUID
    var type: SectionType
    var number: Int? // e.g., Verse 1, Verse 2

    init(type: SectionType, number: Int? = nil) {
        self.id = UUID()
        self.type = type
        self.number = number
    }

    var displayName: String {
        if let number = number {
            return "\(type.rawValue) \(number)"
        }
        return type.rawValue
    }
}

struct LyricLine: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var rhymeLabel: String?
    var syllableCount: Int
    var endWord: String
    var sectionId: UUID?         // Which section this line belongs to
    var labelOverride: String?   // Manual rhyme label override (persisted)
    /// Stress pattern for the line: 1 = stressed, 0 = unstressed
    var stressPattern: [Int]

    init(text: String = "", rhymeLabel: String? = nil, sectionId: UUID? = nil) {
        self.id = UUID()
        self.text = text
        self.rhymeLabel = rhymeLabel
        self.sectionId = sectionId
        self.syllableCount = SyllableCounter.count(text)
        self.endWord = LyricLine.extractEndWord(from: text)
        self.stressPattern = StressAnalyzer.analyzeStress(text)
        self.labelOverride = nil
    }

    // Handle decoding from older data that lacks new fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        rhymeLabel = try container.decodeIfPresent(String.self, forKey: .rhymeLabel)
        syllableCount = try container.decode(Int.self, forKey: .syllableCount)
        endWord = try container.decode(String.self, forKey: .endWord)
        sectionId = try container.decodeIfPresent(UUID.self, forKey: .sectionId)
        labelOverride = try container.decodeIfPresent(String.self, forKey: .labelOverride)
        stressPattern = try container.decodeIfPresent([Int].self, forKey: .stressPattern) ?? StressAnalyzer.analyzeStress(text)
    }

    mutating func updateText(_ newText: String) {
        text = newText
        syllableCount = SyllableCounter.count(newText)
        endWord = LyricLine.extractEndWord(from: newText)
        stressPattern = StressAnalyzer.analyzeStress(newText)
    }

    static func extractEndWord(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let last = words.last else { return "" }
        return last.lowercased().filter { $0.isLetter || $0 == "'" || $0 == "-" }
    }
}
