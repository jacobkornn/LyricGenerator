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
