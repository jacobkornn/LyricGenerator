import Foundation
import SwiftUI
import Combine

@MainActor
class LyricViewModel: ObservableObject {
    @Published var lines: [LyricLine] = [LyricLine()]
    @Published var rhymeLabels: [String?] = [nil]
    /// Manual label overrides by line ID
    var labelOverrides: [UUID: String] = [:]
    @Published var schemeString: String = ""
    @Published var suggestions: [RhymeService.RhymeWord] = []
    @Published var suggestionsTargetLabel: String? = nil
    @Published var suggestionsTargetWord: String? = nil
    @Published var lockedEndWord: String? = nil
    @Published var currentLineIndex: Int = 0
    @Published var entries: [LyricEntry] = []
    @Published var currentEntryId: UUID? = nil
    @Published var isDark: Bool = true
    @Published var wordBank: [String] = []
    @Published var wordBankExpanded: Bool = false
    @Published var customTitle: String = ""
    /// 0.0 = very loose (ending match), 0.5 = moderate, 1.0 = strict (perfect rhymes only)
    @Published var rhymeSensitivity: Double = 0.5 {
        didSet {
            UserDefaults.standard.set(rhymeSensitivity, forKey: "lyric_rhyme_sensitivity")
            // Re-evaluate scheme, and reload suggestions if they're already showing
            if !suggestions.isEmpty {
                refreshSchemeAndFetchSuggestions()
            } else {
                refreshScheme()
            }
        }
    }

    private let rhymeService = RhymeService.shared
    private var schemeTask: Task<Void, Never>?
    private var suggestionTask: Task<Void, Never>?
    private var undoStack: [[LyricLine]] = []
    private let maxUndoSteps = 30

    init() {
        entries = StorageService.loadEntries()
        if let pref = UserDefaults.standard.object(forKey: "lyric_dark_mode") as? Bool {
            isDark = pref
        }
        if UserDefaults.standard.object(forKey: "lyric_rhyme_sensitivity") != nil {
            rhymeSensitivity = UserDefaults.standard.double(forKey: "lyric_rhyme_sensitivity")
        }
    }

    // MARK: - Line Management

    func commitLine(at index: Int) {
        // Save undo state before committing
        pushUndo()

        // If there's a locked word, ensure it's appended
        if let locked = lockedEndWord {
            let currentText = lines[index].text.trimmingCharacters(in: .whitespaces)
            if !currentText.lowercased().hasSuffix(locked.lowercased()) {
                lines[index].updateText(currentText.isEmpty ? locked : "\(currentText) \(locked)")
            }
            lockedEndWord = nil
        }

        // Finalize the line
        lines[index].updateText(lines[index].text)

        // Add new empty line
        let newLine = LyricLine()
        if index == lines.count - 1 {
            lines.append(newLine)
        } else {
            lines.insert(newLine, at: index + 1)
        }
        currentLineIndex = index + 1

        // Recalculate scheme then fetch suggestions (in sequence)
        refreshSchemeAndFetchSuggestions()
        autoSave()
    }

    func updateLineText(at index: Int, text: String) {
        guard index < lines.count else { return }
        lines[index].updateText(text)
    }

    /// Delete an empty line when backspace is pressed on it
    func deleteEmptyLine(at index: Int) {
        guard index > 0, index < lines.count else { return }
        guard lines[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        pushUndo()
        lines.remove(at: index)
        currentLineIndex = index - 1
        refreshScheme()
        autoSave()
    }

    func overrideLabel(at index: Int, to newLabel: String) {
        guard index < lines.count else { return }
        labelOverrides[lines[index].id] = newLabel
        // Apply override immediately
        if index < rhymeLabels.count {
            rhymeLabels[index] = newLabel
            schemeString = rhymeLabels.compactMap { $0 }.joined()
        }
    }

    // MARK: - Rhyme Scheme

    /// Refresh scheme and return the labels (awaitable)
    private func performSchemeRefresh() async -> [String?] {
        let completedLines = lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        let labels = await rhymeService.assignScheme(to: completedLines, sensitivity: rhymeSensitivity)

        guard !Task.isCancelled else { return [] }

        // Map labels back to all lines
        var fullLabels: [String?] = []
        var labelIdx = 0
        for line in lines {
            if !line.text.trimmingCharacters(in: .whitespaces).isEmpty && labelIdx < labels.count {
                fullLabels.append(labels[labelIdx])
                labelIdx += 1
            } else {
                fullLabels.append(nil)
            }
        }

        // Apply manual overrides
        for (i, line) in lines.enumerated() {
            if let override = labelOverrides[line.id] {
                fullLabels[i] = override
            }
        }

        rhymeLabels = fullLabels
        schemeString = labels.compactMap { $0 }.joined()
        return fullLabels
    }

    func refreshScheme() {
        schemeTask?.cancel()
        schemeTask = Task { _ = await performSchemeRefresh() }
    }

    // MARK: - Suggestions

    func refreshSchemeAndFetchSuggestions() {
        schemeTask?.cancel()
        suggestionTask?.cancel()
        schemeTask = Task {
            // First: refresh the scheme and wait for it
            let freshLabels = await performSchemeRefresh()
            guard !Task.isCancelled else { return }

            // Now fetch suggestions using the fresh labels
            await performSuggestionFetch(using: freshLabels)
        }
    }

    private func performSuggestionFetch(using freshLabels: [String?]) async {
        let completedLabels = freshLabels.enumerated()
            .filter { i, _ in i < lines.count && !lines[i].text.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.1 }

        let predicted = await rhymeService.predictNextLabel(from: completedLabels)
        guard let predicted = predicted else {
            suggestions = []
            suggestionsTargetLabel = nil
            suggestionsTargetWord = nil
            return
        }

        guard !Task.isCancelled else { return }

        // Find the target word to rhyme with
        var targetWord: String? = nil
        for (i, label) in freshLabels.enumerated().reversed() {
            if label == predicted && i < lines.count && !lines[i].endWord.isEmpty {
                targetWord = lines[i].endWord
                break
            }
        }

        guard let target = targetWord else {
            suggestions = []
            suggestionsTargetLabel = nil
            suggestionsTargetWord = nil
            return
        }

        // Calculate average syllable count of completed lines for flow matching
        let completedLines = lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        let avgSyllables: Int? = completedLines.isEmpty ? nil : {
            let total = completedLines.reduce(0) { $0 + $1.syllableCount }
            let avg = total / completedLines.count
            let currentSyllables = lines[safe: currentLineIndex]?.syllableCount ?? 0
            let remaining = max(1, avg - currentSyllables)
            return remaining
        }()

        // Get API suggestions
        var results = await rhymeService.getSuggestions(for: target, targetSyllables: avgSyllables, sensitivity: rhymeSensitivity)
        guard !Task.isCancelled else { return }

        // Prepend word bank matches that rhyme with the target
        let bankMatches = await wordBankRhymes(for: target)
        if !bankMatches.isEmpty {
            let bankWords = bankMatches.map {
                RhymeService.RhymeWord(word: $0, score: 10000, numSyllables: SyllableCounter.countWord($0))
            }
            results = bankWords + results.filter { w in !bankMatches.contains(w.word) }
        }

        suggestions = results
        suggestionsTargetLabel = predicted
        suggestionsTargetWord = target
    }

    private func wordBankRhymes(for target: String) async -> [String] {
        var matches: [String] = []
        for word in wordBank {
            if await rhymeService.doWordsRhyme(word.lowercased(), target.lowercased(), sensitivity: rhymeSensitivity) {
                matches.append(word)
            }
        }
        return matches
    }

    func selectSuggestion(_ word: String) {
        lockedEndWord = word
        suggestions = []
    }

    func clearLockedWord() {
        lockedEndWord = nil
        // Re-fetch suggestions since user cancelled
        refreshSchemeAndFetchSuggestions()
    }

    // MARK: - Word Bank

    func addToWordBank(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !wordBank.contains(trimmed) else { return }
        wordBank.append(trimmed)
        autoSave()
    }

    func removeFromWordBank(_ word: String) {
        wordBank.removeAll { $0 == word }
        autoSave()
    }

    // MARK: - Entry Management

    func autoSave() {
        let hasContent = lines.contains { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        guard hasContent else { return }

        if let entryId = currentEntryId, let idx = entries.firstIndex(where: { $0.id == entryId }) {
            entries[idx].lines = lines
            entries[idx].wordBank = wordBank
            entries[idx].customTitle = customTitle
            entries[idx].refreshTitle()
        } else {
            var entry = LyricEntry(lines: lines, wordBank: wordBank, customTitle: customTitle)
            entry.lines = lines
            entry.wordBank = wordBank
            entry.customTitle = customTitle
            entry.refreshTitle()
            entries.insert(entry, at: 0)
            currentEntryId = entry.id
        }
        StorageService.saveEntries(entries)
    }

    func loadEntry(_ entry: LyricEntry) {
        lines = entry.lines
        wordBank = entry.wordBank
        customTitle = entry.customTitle
        if lines.isEmpty { lines = [LyricLine()] }
        currentEntryId = entry.id
        currentLineIndex = max(0, lines.count - 1)
        lockedEndWord = nil
        suggestions = []
        refreshScheme()
    }

    func newEntry() {
        autoSave()
        lines = [LyricLine()]
        rhymeLabels = [nil]
        schemeString = ""
        suggestions = []
        suggestionsTargetLabel = nil
        lockedEndWord = nil
        wordBank = []
        customTitle = ""
        currentLineIndex = 0
        currentEntryId = nil
    }

    func deleteEntry(_ entry: LyricEntry) {
        entries.removeAll { $0.id == entry.id }
        if currentEntryId == entry.id {
            // Reset canvas without auto-saving (which would re-create the deleted entry)
            lines = [LyricLine()]
            rhymeLabels = [nil]
            schemeString = ""
            suggestions = []
            suggestionsTargetLabel = nil
            lockedEndWord = nil
            wordBank = []
            customTitle = ""
            currentLineIndex = 0
            currentEntryId = nil
        }
        StorageService.saveEntries(entries)
    }

    // MARK: - Undo

    private func pushUndo() {
        undoStack.append(lines)
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        lines = previous
        currentLineIndex = max(0, lines.count - 1)
        lockedEndWord = nil
        suggestions = []
        refreshScheme()
        autoSave()
    }

    var canUndo: Bool { !undoStack.isEmpty }

    /// Average syllable count of completed lines (for flow target)
    var averageSyllableCount: Int? {
        let completed = lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !completed.isEmpty else { return nil }
        let total = completed.reduce(0) { $0 + $1.syllableCount }
        return total / completed.count
    }

    func toggleTheme() {
        isDark.toggle()
        UserDefaults.standard.set(isDark, forKey: "lyric_dark_mode")
    }
}

// Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
