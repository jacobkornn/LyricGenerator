import Foundation
import SwiftUI
import Combine

/// Represents a single undo action for granular undo
enum UndoAction {
    case textChange(lineIndex: Int, oldText: String, oldSyllables: Int, oldEndWord: String, oldStress: [Int])
    case lineAdded(lineIndex: Int)
    case lineRemoved(lineIndex: Int, line: LyricLine)
    case labelOverride(lineId: UUID, oldLabel: String?)
    case sectionAdded(sectionIndex: Int)
    case sectionRemoved(sectionIndex: Int, section: SectionMarker)
}

@MainActor
class LyricViewModel: ObservableObject {
    @Published var lines: [LyricLine] = [LyricLine()]
    @Published var rhymeLabels: [String?] = [nil]
    @Published var schemeString: String = ""
    @Published var suggestions: [RhymeService.RhymeWord] = []
    @Published var suggestionsTargetLabel: String? = nil
    @Published var suggestionsTargetWord: String? = nil
    @Published var lockedEndWord: String? = nil
    @Published var currentLineIndex: Int = -1  // -1 = no active line
    @Published var entries: [LyricEntry] = []
    @Published var currentEntryId: UUID? = nil
    @Published var isDark: Bool = true
    @Published var wordBank: [String] = []
    @Published var wordBankExpanded: Bool = false
    @Published var customTitle: String = ""
    @Published var isLoadingSuggestions: Bool = false
    @Published var selectedSuggestionIndex: Int = -1
    @Published var suggestionsExpanded: Bool = false
    @Published var sections: [SectionMarker] = []
    @Published var showFlowPattern: Bool = false {
        didSet {
            UserDefaults.standard.set(showFlowPattern, forKey: "lyric_show_flow_pattern")
        }
    }

    /// 0.0 = very loose, 0.5 = moderate, 1.0 = strict
    @Published var rhymeSensitivity: Double = 0.5 {
        didSet {
            UserDefaults.standard.set(rhymeSensitivity, forKey: "lyric_rhyme_sensitivity")
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
    private var undoStack: [UndoAction] = []
    private let maxUndoSteps = 50
    private var debouncedSaveTask: Task<Void, Never>?

    init() {
        entries = StorageService.loadEntries()
        if let pref = UserDefaults.standard.object(forKey: "lyric_dark_mode") as? Bool {
            isDark = pref
        }
        if UserDefaults.standard.object(forKey: "lyric_show_flow_pattern") != nil {
            showFlowPattern = UserDefaults.standard.bool(forKey: "lyric_show_flow_pattern")
        }
        if UserDefaults.standard.object(forKey: "lyric_rhyme_sensitivity") != nil {
            rhymeSensitivity = UserDefaults.standard.double(forKey: "lyric_rhyme_sensitivity")
        }
    }

    // MARK: - Section Management

    func addSection(_ type: SectionType, at lineIndex: Int? = nil) {
        // Auto-number: count existing sections of same type
        let existing = sections.filter { $0.type == type }.count
        let number = (type == .chorus || type == .bridge) ? nil : existing + 1
        let section = SectionMarker(type: type, number: number)
        sections.append(section)

        if let lineIndex = lineIndex, lineIndex >= 0 && lineIndex < lines.count {
            lines[lineIndex].sectionId = section.id
        } else {
            // Insert after the current line, or after the last non-empty line
            let lastContentIndex = lines.lastIndex(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }) ?? -1
            let insertIndex: Int
            if currentLineIndex >= 0 && currentLineIndex < lines.count {
                insertIndex = currentLineIndex + 1
            } else {
                insertIndex = max(lastContentIndex + 1, 0)
            }
            let safeInsert = min(insertIndex, lines.count)
            let newLine = LyricLine(sectionId: section.id)
            lines.insert(newLine, at: safeInsert)
            currentLineIndex = safeInsert
        }

        undoStack.append(.sectionAdded(sectionIndex: sections.count - 1))
        trimUndoStack()
        autoSave()
    }

    func removeSection(at index: Int) {
        guard index < sections.count else { return }
        let removed = sections[index]
        undoStack.append(.sectionRemoved(sectionIndex: index, section: removed))
        trimUndoStack()

        // Clear sectionId from lines
        for i in 0..<lines.count where lines[i].sectionId == removed.id {
            lines[i].sectionId = nil
        }
        sections.remove(at: index)
        cleanupOrphanedSections()
        autoSave()
    }

    /// Remove sections from the array that no line references
    private func cleanupOrphanedSections() {
        let referencedIds = Set(lines.compactMap { $0.sectionId })
        sections.removeAll { !referencedIds.contains($0.id) }
    }

    /// Move a section marker to start at a different line
    func moveSection(sectionId: UUID, toLineIndex: Int) {
        guard toLineIndex >= 0 && toLineIndex < lines.count else { return }
        // Clear old line assignments for this section
        for i in 0..<lines.count where lines[i].sectionId == sectionId {
            lines[i].sectionId = nil
        }
        // Clamp: don't allow section to float past last non-empty line
        let lastContentIndex = lines.lastIndex(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }) ?? 0
        let targetIndex = min(toLineIndex, lastContentIndex + 1)
        // If target is beyond existing lines, clamp to last line
        let safeIndex = min(targetIndex, lines.count - 1)
        lines[safeIndex].sectionId = sectionId
        autoSave()
    }

    func sectionForLine(at index: Int) -> SectionMarker? {
        guard index < lines.count, let sectionId = lines[index].sectionId else { return nil }
        return sections.first { $0.id == sectionId }
    }

    /// Get lines grouped by section for rhyme scheme calculation
    func linesInSameSection(as lineIndex: Int) -> [Int] {
        guard lineIndex < lines.count else { return [] }
        let sectionId = lines[lineIndex].sectionId
        return lines.enumerated()
            .filter { $0.element.sectionId == sectionId }
            .map { $0.offset }
    }

    // MARK: - Line Management

    func commitLine(at index: Int) {
        // Save undo state for the line add
        let oldText = lines[index].text
        let oldSyl = lines[index].syllableCount
        let oldEnd = lines[index].endWord
        let oldStress = lines[index].stressPattern
        undoStack.append(.textChange(lineIndex: index, oldText: oldText, oldSyllables: oldSyl, oldEndWord: oldEnd, oldStress: oldStress))
        trimUndoStack()

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

        // Persist any label override
        if let override = lines[index].labelOverride {
            lines[index].labelOverride = override
        }

        // Add new empty line with same section
        let sectionId = lines[index].sectionId
        var newLine = LyricLine(sectionId: sectionId)
        newLine.sectionId = sectionId
        if index == lines.count - 1 {
            lines.append(newLine)
        } else {
            lines.insert(newLine, at: index + 1)
        }
        undoStack.append(.lineAdded(lineIndex: index + 1))
        trimUndoStack()

        currentLineIndex = index + 1
        selectedSuggestionIndex = -1

        refreshSchemeAndFetchSuggestions()
        autoSave()
    }

    func updateLineText(at index: Int, text: String) {
        guard index < lines.count else { return }
        lines[index].updateText(text)
        debouncedAutoSave()
    }

    /// Debounced save — writes to disk after 1.5s of inactivity
    private func debouncedAutoSave() {
        debouncedSaveTask?.cancel()
        debouncedSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.autoSave()
        }
    }

    /// Delete an empty line when backspace is pressed on it
    func deleteEmptyLine(at index: Int) {
        guard index > 0, index < lines.count else { return }
        guard lines[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let removed = lines[index]
        undoStack.append(.lineRemoved(lineIndex: index, line: removed))
        trimUndoStack()
        lines.remove(at: index)
        currentLineIndex = index - 1
        refreshScheme()
        autoSave()
    }

    func overrideLabel(at index: Int, to newLabel: String) {
        guard index < lines.count else { return }
        let oldLabel = lines[index].labelOverride
        undoStack.append(.labelOverride(lineId: lines[index].id, oldLabel: oldLabel))
        trimUndoStack()

        lines[index].labelOverride = newLabel
        // Apply override immediately
        if index < rhymeLabels.count {
            rhymeLabels[index] = newLabel
            schemeString = rhymeLabels.compactMap { $0 }.joined()
        }
        autoSave()
    }

    // MARK: - Rhyme Scheme

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

        // Apply persisted label overrides
        for (i, line) in lines.enumerated() {
            if let override = line.labelOverride {
                if i < fullLabels.count {
                    fullLabels[i] = override
                }
            }
        }

        rhymeLabels = fullLabels
        schemeString = fullLabels.compactMap { $0 }.joined()
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
        isLoadingSuggestions = true
        schemeTask = Task {
            let freshLabels = await performSchemeRefresh()
            guard !Task.isCancelled else { return }
            await performSuggestionFetch(using: freshLabels)
            if !Task.isCancelled {
                isLoadingSuggestions = false
            }
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

        // Calculate average syllable count for flow matching
        let completedLines = lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        let avgSyllables: Int? = completedLines.isEmpty ? nil : {
            let total = completedLines.reduce(0) { $0 + $1.syllableCount }
            let avg = total / completedLines.count
            let currentSyllables = lines[safe: currentLineIndex]?.syllableCount ?? 0
            let remaining = max(1, avg - currentSyllables)
            return remaining
        }()

        var results = await rhymeService.getSuggestions(for: target, targetSyllables: avgSyllables, sensitivity: rhymeSensitivity)
        guard !Task.isCancelled else { return }

        // Prepend word bank matches
        let bankMatches = await wordBankRhymes(for: target)
        if !bankMatches.isEmpty {
            let bankWords = bankMatches.map {
                RhymeService.RhymeWord(word: $0, score: 10000, numSyllables: SyllableCounter.countWord($0))
            }
            results = bankWords + results.filter { w in !bankMatches.contains(w.word) }
        }

        // Sort by syllable match: closest to the rhyming word's syllable count first
        let targetWordSyllables = SyllableCounter.countWord(target)
        results.sort { a, b in
            let aSyl = a.numSyllables ?? 0
            let bSyl = b.numSyllables ?? 0
            let aDiff = abs(aSyl - targetWordSyllables)
            let bDiff = abs(bSyl - targetWordSyllables)
            if aDiff != bDiff { return aDiff < bDiff }
            return (a.score ?? 0) > (b.score ?? 0)
        }

        suggestions = results
        suggestionsTargetLabel = predicted
        suggestionsTargetWord = target
        selectedSuggestionIndex = -1
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

    // MARK: - Suggestion Keyboard Navigation

    func selectNextSuggestion() {
        guard !suggestions.isEmpty else { return }
        selectedSuggestionIndex = min(selectedSuggestionIndex + 1, suggestions.count - 1)
    }

    func selectPreviousSuggestion() {
        guard !suggestions.isEmpty else { return }
        selectedSuggestionIndex = max(selectedSuggestionIndex - 1, -1)
    }

    func confirmSelectedSuggestion() {
        guard selectedSuggestionIndex >= 0 && selectedSuggestionIndex < suggestions.count else { return }
        selectSuggestion(suggestions[selectedSuggestionIndex].word)
    }

    func dismissSuggestions() {
        selectedSuggestionIndex = -1
        suggestions = []
        suggestionsExpanded = false
    }

    func selectSuggestion(_ word: String) {
        lockedEndWord = word
        suggestions = []
        selectedSuggestionIndex = -1
        suggestionsExpanded = false
    }

    func clearLockedWord() {
        lockedEndWord = nil
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
            entries[idx].sections = sections
            entries[idx].refreshTitle()
        } else {
            var entry = LyricEntry(lines: lines, wordBank: wordBank, customTitle: customTitle, sections: sections)
            entry.lines = lines
            entry.wordBank = wordBank
            entry.customTitle = customTitle
            entry.sections = sections
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
        sections = entry.sections
        cleanupOrphanedSections()
        if lines.isEmpty { lines = [LyricLine()] }
        currentEntryId = entry.id
        currentLineIndex = -1
        lockedEndWord = nil
        suggestions = []
        selectedSuggestionIndex = -1
        undoStack = []
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
        sections = []
        currentLineIndex = 0
        currentEntryId = nil
        selectedSuggestionIndex = -1
        undoStack = []
    }

    func deleteEntry(_ entry: LyricEntry) {
        entries.removeAll { $0.id == entry.id }
        if currentEntryId == entry.id {
            lines = [LyricLine()]
            rhymeLabels = [nil]
            schemeString = ""
            suggestions = []
            suggestionsTargetLabel = nil
            lockedEndWord = nil
            wordBank = []
            customTitle = ""
            sections = []
            currentLineIndex = -1
            currentEntryId = nil
            selectedSuggestionIndex = -1
        }
        StorageService.saveEntries(entries)
    }

    // MARK: - Granular Undo

    private func trimUndoStack() {
        while undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }
    }

    func undo() {
        guard let action = undoStack.popLast() else { return }
        switch action {
        case .textChange(let lineIndex, let oldText, let oldSyl, let oldEnd, let oldStress):
            if lineIndex < lines.count {
                lines[lineIndex].text = oldText
                lines[lineIndex].syllableCount = oldSyl
                lines[lineIndex].endWord = oldEnd
                lines[lineIndex].stressPattern = oldStress
                currentLineIndex = lineIndex
            }
        case .lineAdded(let lineIndex):
            if lineIndex < lines.count {
                lines.remove(at: lineIndex)
                currentLineIndex = max(0, lineIndex - 1)
            }
        case .lineRemoved(let lineIndex, let line):
            lines.insert(line, at: min(lineIndex, lines.count))
            currentLineIndex = lineIndex
        case .labelOverride(let lineId, let oldLabel):
            if let idx = lines.firstIndex(where: { $0.id == lineId }) {
                lines[idx].labelOverride = oldLabel
            }
        case .sectionAdded(let sectionIndex):
            if sectionIndex < sections.count {
                let section = sections[sectionIndex]
                for i in 0..<lines.count where lines[i].sectionId == section.id {
                    lines[i].sectionId = nil
                }
                sections.remove(at: sectionIndex)
            }
        case .sectionRemoved(let sectionIndex, let section):
            sections.insert(section, at: min(sectionIndex, sections.count))
        }

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

    // MARK: - Rhyme Map Data

    /// Returns connections between lines that rhyme (for visualization)
    var rhymeConnections: [(from: Int, to: Int, label: String)] {
        var connections: [(Int, Int, String)] = []
        var labelGroups: [String: [Int]] = [:]

        for (i, label) in rhymeLabels.enumerated() {
            guard let label = label else { continue }
            if !lines[i].text.trimmingCharacters(in: .whitespaces).isEmpty {
                labelGroups[label, default: []].append(i)
            }
        }

        for (label, indices) in labelGroups where indices.count > 1 {
            for i in 0..<indices.count - 1 {
                connections.append((indices[i], indices[i + 1], label))
            }
        }

        return connections
    }

    // MARK: - Export

    func exportPlainText() -> String {
        var output = ""
        if !customTitle.isEmpty {
            output += customTitle + "\n\n"
        }

        var currentSectionId: UUID? = nil
        for line in lines {
            if line.sectionId != currentSectionId, let sectionId = line.sectionId,
               let section = sections.first(where: { $0.id == sectionId }) {
                if !output.isEmpty { output += "\n" }
                output += "[\(section.displayName)]\n"
                currentSectionId = sectionId
            }
            let text = line.text.trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                output += text + "\n"
            }
        }
        return output
    }

    func exportAnnotated() -> String {
        var output = ""
        if !customTitle.isEmpty {
            output += customTitle + "\n"
            output += String(repeating: "=", count: customTitle.count) + "\n\n"
        }

        if !schemeString.isEmpty {
            output += "Rhyme Scheme: \(schemeString)\n\n"
        }

        var currentSectionId: UUID? = nil
        for (i, line) in lines.enumerated() {
            if line.sectionId != currentSectionId, let sectionId = line.sectionId,
               let section = sections.first(where: { $0.id == sectionId }) {
                if !output.isEmpty { output += "\n" }
                output += "[\(section.displayName)]\n"
                currentSectionId = sectionId
            }
            let text = line.text.trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                let label = (rhymeLabels[safe: i] ?? nil) ?? " "
                let syl = line.syllableCount
                output += "  \(label) │ \(text) │ \(syl) syl\n"
            }
        }

        if !wordBank.isEmpty {
            output += "\nWord Bank: \(wordBank.joined(separator: ", "))\n"
        }

        return output
    }
}

// Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
