import Foundation
import AppKit

struct AbletonProject: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
}

enum AbletonScanService {
    private static let defaultsKey = "ableton_scan_path"

    static func scanPath() -> URL {
        if let saved = UserDefaults.standard.string(forKey: defaultsKey) {
            return URL(fileURLWithPath: saved)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Music/Ableton")
    }

    static func findMatchingProjects(for title: String) async -> [AbletonProject] {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, trimmed != "untitled" else { return [] }

        let root = scanPath()
        return await Task.detached {
            var results: [AbletonProject] = []
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return results }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension.lowercased() == "als" else { continue }
                let fileName = fileURL.deletingPathExtension().lastPathComponent.lowercased()
                if fileName.contains(trimmed) || trimmed.contains(fileName) {
                    results.append(AbletonProject(name: fileURL.deletingPathExtension().lastPathComponent, url: fileURL))
                }
            }
            return results
        }.value
    }

    @MainActor
    static func chooseDirectory() async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose your Ableton projects folder"

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return nil }
        UserDefaults.standard.set(url.path, forKey: defaultsKey)
        return url
    }
}
