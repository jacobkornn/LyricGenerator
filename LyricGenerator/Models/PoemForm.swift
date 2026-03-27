import Foundation

enum PoemForm: String, Codable, CaseIterable {
    case freeVerse
    case haiku
    case sonnet
    case limerick
    case villanelle
    case couplets

    var displayName: String {
        switch self {
        case .freeVerse:   return "Free Verse"
        case .haiku:       return "Haiku"
        case .sonnet:      return "Sonnet"
        case .limerick:    return "Limerick"
        case .villanelle:  return "Villanelle"
        case .couplets:    return "Couplets"
        }
    }

    /// Fixed number of lines for this form, or nil if unlimited.
    var lineCount: Int? {
        switch self {
        case .freeVerse:   return nil
        case .haiku:       return 3
        case .sonnet:      return 14
        case .limerick:    return 5
        case .villanelle:  return 19
        case .couplets:    return nil
        }
    }

    /// Per-line syllable targets, or nil if unconstrained.
    var syllablePattern: [Int]? {
        switch self {
        case .haiku:    return [5, 7, 5]
        case .limerick: return [8, 8, 5, 5, 8]
        default:        return nil
        }
    }

    /// Expected rhyme scheme template, or nil if none.
    var rhymeSchemeTemplate: String? {
        switch self {
        case .freeVerse:   return nil
        case .haiku:       return nil
        case .sonnet:      return "ABAB CDCD EFEF GG"
        case .limerick:    return "AABBA"
        case .villanelle:  return "ABA ABA ABA ABA ABA ABAA"
        case .couplets:    return "AA BB CC ..."
        }
    }

    /// Per-line rhyme labels expanded from the template, or nil if no fixed scheme.
    var rhymeLabelsPerLine: [String?]? {
        switch self {
        case .haiku:       return [nil, nil, nil]
        case .sonnet:      return ["A","B","A","B","C","D","C","D","E","F","E","F","G","G"]
        case .limerick:    return ["A","A","B","B","A"]
        case .villanelle:  return ["A","B","A","A","B","A","A","B","A","A","B","A","A","B","A","A","B","A","A"]
        default:           return nil
        }
    }

    /// Line indices where stanza breaks should occur (section headers inserted before these lines).
    var stanzaBreaks: [Int]? {
        switch self {
        case .sonnet:      return [0, 4, 8, 12]  // 3 quatrains + couplet
        case .villanelle:  return [0, 3, 6, 9, 12, 15]  // 5 tercets + quatrain
        default:           return nil
        }
    }

    /// Whether this form has a fixed template (static line count).
    var hasTemplate: Bool { lineCount != nil }

    /// Short description for the form picker.
    var description: String {
        switch self {
        case .freeVerse:   return "No fixed structure"
        case .haiku:       return "3 lines: 5-7-5 syllables"
        case .sonnet:      return "14 lines, iambic pentameter"
        case .limerick:    return "5 lines, AABBA rhyme"
        case .villanelle:  return "19 lines, two refrains"
        case .couplets:    return "Paired rhyming lines"
        }
    }
}
