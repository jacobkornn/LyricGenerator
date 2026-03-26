import Foundation

enum EntryMode: String, Codable, CaseIterable {
    case lyrics
    case poem
    case free

    var displayName: String {
        switch self {
        case .lyrics: return "Lyrics"
        case .poem:   return "Poem"
        case .free:   return "Free"
        }
    }

    var icon: String {
        switch self {
        case .lyrics: return "music.note.list"
        case .poem:   return "text.book.closed"
        case .free:   return "note.text"
        }
    }
}
