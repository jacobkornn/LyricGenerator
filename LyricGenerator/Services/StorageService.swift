import Foundation

enum StorageService {
    private static let dirName = "LyricGenerator"
    private static let fileName = "entries.json"

    private static var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent(dirName)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(fileName)
    }

    static func loadEntries() -> [LyricEntry] {
        let url = storageURL

        // Try file-based storage first
        if let data = try? Data(contentsOf: url) {
            if let entries = try? JSONDecoder().decode([LyricEntry].self, from: data) {
                return entries
            }
        }

        // Fall back to UserDefaults for one-time migration
        if let legacyData = UserDefaults.standard.data(forKey: "lyric_generator_entries") {
            if let entries = try? JSONDecoder().decode([LyricEntry].self, from: legacyData) {
                // Migrate to file storage and remove from UserDefaults
                saveEntries(entries)
                UserDefaults.standard.removeObject(forKey: "lyric_generator_entries")
                return entries
            }
        }

        return []
    }

    static func saveEntries(_ entries: [LyricEntry]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
