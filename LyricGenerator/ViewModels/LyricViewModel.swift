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

/// Represents a dropdown option pairing a rhyme label with its ending sound.
struct LabelOption: Identifiable, Equatable {
    let label: String
    let ending: String
    let targetWord: String
    var id: String { "\(label)|\(ending)" }

    /// Extract the phonetic ending of a word (from the last vowel cluster onward).
    /// e.g. "night" → "ight", "day" → "ay", "love" → "ove", "brain" → "ain"
    static func extractEnding(from word: String) -> String {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        let lower = word.lowercased().filter { $0.isLetter }
        guard !lower.isEmpty else { return word }
        let chars = Array(lower)

        // Walk backwards to find the start of the rhyming portion:
        // Find the last vowel cluster and include it + trailing consonants
        var i = chars.count - 1

        // Skip trailing consonants
        while i >= 0 && !vowels.contains(chars[i]) {
            i -= 1
        }
        // Skip the vowel cluster
        while i >= 0 && vowels.contains(chars[i]) {
            i -= 1
        }

        let ending = String(chars[(i + 1)...])
        // If the ending is the whole word (e.g., short words), just return it
        return ending.isEmpty ? lower : ending
    }
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
    @Published var suggestionsOverrideLabel: String? = nil
    @Published var suggestionsOverrideWord: String? = nil
    @Published var sections: [SectionMarker] = []
    @Published var isDraggingSection: Bool = false
    @Published var currentMode: EntryMode = .lyrics
    @Published var currentPoemForm: PoemForm? = nil
    @Published var selectedLines: Set<Int> = []

    /// True when more than one line is selected (multi-select mode).
    var hasMultiLineSelection: Bool { selectedLines.count > 1 }

    /// Select all lines (Cmd+A behaviour).
    func selectAllLines() {
        selectedLines = Set(0..<lines.count)
        currentLineIndex = -1
    }

    /// Clear multi-line selection (called when user focuses a single line).
    func clearMultiLineSelection() {
        if !selectedLines.isEmpty { selectedLines = [] }
    }

    /// Per-mode snapshot so each tab preserves its own content.
    struct ModeSnapshot {
        var lines: [LyricLine]
        var sections: [SectionMarker]
        var rhymeLabels: [String?]
        var schemeString: String
        var currentLineIndex: Int
        var poemForm: PoemForm?
    }
    var modeSnapshots: [EntryMode: ModeSnapshot] = [:]
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
    private var redoStack: [UndoAction] = []
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
            // Default: place section on the first line (before content)
            // If no sections exist yet, attach to line 0
            // If sections already exist, insert after current line or at end of content
            if sections.count == 1 && lines.first != nil {
                // This is the first section — place it at the very start
                lines[0].sectionId = section.id
            } else {
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
        }

        pushUndo(.sectionAdded(sectionIndex: sections.count - 1))
        autoSave()
    }

    func removeSection(at index: Int) {
        guard index < sections.count else { return }
        let removed = sections[index]
        pushUndo(.sectionRemoved(sectionIndex: index, section: removed))

        // Clear sectionId from lines
        for i in 0..<lines.count where lines[i].sectionId == removed.id {
            lines[i].sectionId = nil
        }
        sections.remove(at: index)
        cleanupOrphanedSections()
        renumberSections()
        autoSave()
    }

    /// Remove sections from the array that no line references
    private func cleanupOrphanedSections() {
        let referencedIds = Set(lines.compactMap { $0.sectionId })
        sections.removeAll { !referencedIds.contains($0.id) }
    }

    /// Renumber sections of the same type sequentially based on their order in `lines`.
    /// For example, after deleting Hook 1 out of Hook 1/2/3, the remaining become Hook 1/2.
    /// Chorus and Bridge are excluded (they always have nil numbers).
    private func renumberSections() {
        // Build a map from sectionId → first line index it appears on
        var sectionLineIndex: [UUID: Int] = [:]
        for (i, line) in lines.enumerated() {
            if let sid = line.sectionId, sectionLineIndex[sid] == nil {
                sectionLineIndex[sid] = i
            }
        }

        // Group section indices by type, sorted by their position in lines
        var typeGroups: [SectionType: [Int]] = [:]
        for (si, section) in sections.enumerated() {
            typeGroups[section.type, default: []].append(si)
        }

        for (type, indices) in typeGroups {
            // Chorus and Bridge don't get numbers
            if type == .chorus || type == .bridge { continue }

            // Sort by position in lines
            let sorted = indices.sorted { a, b in
                let posA = sectionLineIndex[sections[a].id] ?? Int.max
                let posB = sectionLineIndex[sections[b].id] ?? Int.max
                return posA < posB
            }

            for (rank, sectionIndex) in sorted.enumerated() {
                sections[sectionIndex].number = rank + 1
            }
        }
    }

    /// Remove trailing empty lines on load, keeping at most one blank line after content
    private func trimTrailingEmptyLines() {
        let lastContentIndex = lines.lastIndex(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }) ?? -1
        let keepCount = lastContentIndex + 2 // keep one empty line after last content
        if lines.count > keepCount && keepCount > 0 {
            lines = Array(lines.prefix(keepCount))
        }
    }

    /// Move a section marker to start at a different line.
    /// Snaps to the nearest non-blank line so it never lands in a blank-line gap.
    func moveSection(sectionId: UUID, toLineIndex: Int) {
        guard toLineIndex >= 0 && toLineIndex < lines.count else { return }
        // Clear old line assignments for this section
        for i in 0..<lines.count where lines[i].sectionId == sectionId {
            lines[i].sectionId = nil
        }
        // Clamp: don't allow section to float past last non-empty line
        let lastContentIndex = lines.lastIndex(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }) ?? 0
        let clampedIndex = min(toLineIndex, lastContentIndex + 1)
        let safeIndex = min(clampedIndex, lines.count - 1)

        // Snap: if target is a blank line, find the nearest non-blank line
        let finalIndex = snapToNearestContent(from: safeIndex)
        lines[finalIndex].sectionId = sectionId
        renumberSections()
        autoSave()
    }

    /// Find the nearest line that has content (or is at index 0).
    /// Searches outward from `index`, preferring forward (next content block).
    private func snapToNearestContent(from index: Int) -> Int {
        // If already on content or at the very start, use it
        if index == 0 || !lines[index].text.trimmingCharacters(in: .whitespaces).isEmpty {
            return index
        }
        // Search outward for nearest non-blank line
        var lo = index - 1
        var hi = index + 1
        while lo >= 0 || hi < lines.count {
            // Prefer forward: snap to the start of the next content block
            if hi < lines.count && !lines[hi].text.trimmingCharacters(in: .whitespaces).isEmpty {
                return hi
            }
            // Backward: snap to the line just after the previous content
            if lo >= 0 && !lines[lo].text.trimmingCharacters(in: .whitespaces).isEmpty {
                // Place section on the line after the previous content line,
                // unless that's where we started (a blank), in which case use lo
                let after = lo + 1
                return after < lines.count ? after : lo
            }
            lo -= 1
            hi += 1
        }
        return index
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
        pushUndo(.textChange(lineIndex: index, oldText: oldText, oldSyllables: oldSyl, oldEndWord: oldEnd, oldStress: oldStress))

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

        if isTemplateMode {
            // Template mode: just move to the next line, don't create one
            if index + 1 < lines.count {
                currentLineIndex = index + 1
            }
        } else {
            // Normal mode: add new empty line
            let sectionId = lines[index].sectionId
            var newLine = LyricLine(sectionId: sectionId)
            newLine.sectionId = sectionId
            if index == lines.count - 1 {
                lines.append(newLine)
            } else {
                lines.insert(newLine, at: index + 1)
            }
            pushUndo(.lineAdded(lineIndex: index + 1))
            currentLineIndex = index + 1
        }

        selectedSuggestionIndex = -1

        if currentMode != .free {
            refreshSchemeAndFetchSuggestions()
        }
        autoSave()
    }

    func updateLineText(at index: Int, text: String) {
        guard index < lines.count else { return }
        lines[index].updateText(text)
        suggestionsOverrideLabel = nil
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
        // Don't delete lines in template mode — structure is static
        guard !isTemplateMode else {
            // Just move to previous line
            if index > 0 { currentLineIndex = index - 1 }
            return
        }
        guard index > 0, index < lines.count else { return }
        guard lines[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let removed = lines[index]
        pushUndo(.lineRemoved(lineIndex: index, line: removed))
        lines.remove(at: index)
        currentLineIndex = index - 1
        refreshScheme()
        autoSave()
    }

    func overrideLabel(at index: Int, to newLabel: String) {
        guard index < lines.count else { return }
        let oldLabel = lines[index].labelOverride
        pushUndo(.labelOverride(lineId: lines[index].id, oldLabel: oldLabel))

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
        // Template mode: labels are static, don't re-detect
        guard !isTemplateMode else { return }
        schemeTask?.cancel()
        schemeTask = Task { _ = await performSchemeRefresh() }
    }

    // MARK: - Suggestions

    func refreshSchemeAndFetchSuggestions() {
        // Free mode: only show word bank suggestions, skip rhyme service
        if currentMode == .free {
            schemeString = ""
            rhymeLabels = Array(repeating: nil, count: lines.count)
            if !wordBank.isEmpty {
                suggestions = wordBank.map {
                    RhymeService.RhymeWord(word: $0, score: 10000, numSyllables: SyllableCounter.countWord($0))
                }
            } else {
                suggestions = []
            }
            isLoadingSuggestions = false
            return
        }

        // Template mode: labels are static, just fetch suggestions based on them
        if isTemplateMode {
            schemeTask?.cancel()
            suggestionTask?.cancel()
            isLoadingSuggestions = true
            schemeTask = Task {
                // Use existing labels directly — don't re-detect scheme
                await performSuggestionFetch(using: rhymeLabels)
                if !Task.isCancelled {
                    isLoadingSuggestions = false
                }
            }
            return
        }

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

        let autoLabel = await rhymeService.predictNextLabel(from: completedLabels)
        guard !Task.isCancelled else { return }
        var predicted = suggestionsOverrideLabel ?? autoLabel

        // Find the target word to rhyme with for the predicted label
        var targetWord: String? = suggestionsOverrideWord
        if targetWord == nil, let p = predicted {
            for (i, label) in freshLabels.enumerated().reversed() {
                if label == p && i < lines.count && !lines[i].endWord.isEmpty {
                    targetWord = lines[i].endWord
                    break
                }
            }
        }

        // Fallback: if no prediction or no target word, use the most recent label
        // that has a rhymeable end word so suggestions always appear
        if targetWord == nil {
            for (i, label) in freshLabels.enumerated().reversed() {
                if let label = label, i < lines.count && !lines[i].endWord.isEmpty {
                    predicted = label
                    targetWord = lines[i].endWord
                    break
                }
            }
        }

        guard !Task.isCancelled else { return }
        guard let predicted = predicted, let target = targetWord else {
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
        guard !Task.isCancelled else { return }
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

    /// Unique rhyme labels currently in use (e.g. ["A", "B", "C", "D"]).
    var availableRhymeLabels: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for label in rhymeLabels.compactMap({ $0 }) {
            if seen.insert(label).inserted {
                result.append(label)
            }
        }
        return result
    }

    /// Label options with ending sounds for the suggestion picker.
    /// Each unique (label, ending) pair gets its own entry so the user
    /// can target a specific ending within the same rhyme group.
    var availableRhymeLabelOptions: [LabelOption] {
        var seen = Set<String>() // "A|ight" dedup key
        var result: [LabelOption] = []
        for (i, label) in rhymeLabels.enumerated() {
            guard let label = label, i < lines.count else { continue }
            let word = lines[i].endWord
            guard !word.isEmpty else { continue }
            let ending = LabelOption.extractEnding(from: word)
            let key = "\(label)|\(ending)"
            if seen.insert(key).inserted {
                result.append(LabelOption(label: label, ending: ending, targetWord: word))
            }
        }
        return result
    }

    /// Switch which label suggestions are tailored to.
    func switchSuggestionLabel(to label: String?) {
        suggestionsOverrideLabel = label
        suggestionsOverrideWord = nil
        suggestionTask?.cancel()
        isLoadingSuggestions = true
        suggestionTask = Task {
            await performSuggestionFetch(using: rhymeLabels)
            if !Task.isCancelled {
                isLoadingSuggestions = false
            }
        }
    }

    /// Switch suggestions to a specific label + target word (for ending-specific selection).
    func switchSuggestionLabel(to label: String?, targetWord: String?) {
        suggestionsOverrideLabel = label
        suggestionsOverrideWord = targetWord
        suggestionTask?.cancel()
        isLoadingSuggestions = true
        suggestionTask = Task {
            await performSuggestionFetch(using: rhymeLabels)
            if !Task.isCancelled {
                isLoadingSuggestions = false
            }
        }
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
            entries[idx].mode = currentMode
            entries[idx].poemForm = currentPoemForm
            entries[idx].refreshTitle()
        } else {
            var entry = LyricEntry(lines: lines, wordBank: wordBank, customTitle: customTitle, sections: sections, mode: currentMode, poemForm: currentPoemForm)
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
        modeSnapshots = [:]  // Clear snapshots when switching entries
        lines = entry.lines
        wordBank = entry.wordBank
        customTitle = entry.customTitle
        sections = entry.sections
        currentMode = entry.mode
        currentPoemForm = entry.poemForm
        cleanupOrphanedSections()
        renumberSections()
        trimTrailingEmptyLines()
        if lines.isEmpty { lines = [LyricLine()] }
        currentEntryId = entry.id
        currentLineIndex = -1
        lockedEndWord = nil
        suggestions = []
        selectedSuggestionIndex = -1
        undoStack = []
        redoStack = []
        if currentMode != .free {
            refreshScheme()
        }
    }

    func newEntry(mode: EntryMode = .lyrics) {
        autoSave()
        modeSnapshots = [:]  // Clear snapshots for new entry
        lines = [LyricLine()]
        rhymeLabels = [nil]
        schemeString = ""
        suggestions = []
        suggestionsTargetLabel = nil
        lockedEndWord = nil
        wordBank = []
        customTitle = ""
        sections = []
        currentMode = mode
        currentPoemForm = nil
        currentLineIndex = 0
        currentEntryId = nil
        selectedSuggestionIndex = -1
        undoStack = []
        redoStack = []
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

    // MARK: - Granular Undo / Redo

    /// Push to undo stack and clear redo history (a new action invalidates the redo future).
    private func pushUndo(_ action: UndoAction) {
        undoStack.append(action)
        redoStack = []
        while undoStack.count > maxUndoSteps { undoStack.removeFirst() }
    }

    private func trimUndoStack() {
        while undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }
    }

    /// Capture the inverse of `action` against the *current* state so it can be re-applied later.
    private func captureInverse(of action: UndoAction) -> UndoAction? {
        switch action {
        case .textChange(let lineIndex, _, _, _, _):
            guard lineIndex < lines.count else { return nil }
            let l = lines[lineIndex]
            return .textChange(lineIndex: lineIndex, oldText: l.text, oldSyllables: l.syllableCount, oldEndWord: l.endWord, oldStress: l.stressPattern)
        case .lineAdded(let lineIndex):
            guard lineIndex < lines.count else { return nil }
            return .lineRemoved(lineIndex: lineIndex, line: lines[lineIndex])
        case .lineRemoved(let lineIndex, _):
            return .lineAdded(lineIndex: lineIndex)
        case .labelOverride(let lineId, _):
            guard let idx = lines.firstIndex(where: { $0.id == lineId }) else { return nil }
            return .labelOverride(lineId: lineId, oldLabel: lines[idx].labelOverride)
        case .sectionAdded(let sectionIndex):
            guard sectionIndex < sections.count else { return nil }
            return .sectionRemoved(sectionIndex: sectionIndex, section: sections[sectionIndex])
        case .sectionRemoved(let sectionIndex, _):
            return .sectionAdded(sectionIndex: sectionIndex)
        }
    }

    /// Apply an action (used by both undo and redo — each action stores the state to restore *to*).
    private func applyAction(_ action: UndoAction) {
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
    }

    func undo() {
        guard let action = undoStack.popLast() else { return }
        let inverse = captureInverse(of: action)
        applyAction(action)
        if let inv = inverse { redoStack.append(inv) }
        lockedEndWord = nil
        suggestions = []
        refreshScheme()
        autoSave()
    }

    func redo() {
        guard let action = redoStack.popLast() else { return }
        let inverse = captureInverse(of: action)
        applyAction(action)
        if let inv = inverse { undoStack.append(inv) }
        lockedEndWord = nil
        suggestions = []
        refreshScheme()
        autoSave()
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Average syllable count of completed lines (for flow target)
    var averageSyllableCount: Int? {
        let completed = lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !completed.isEmpty else { return nil }
        let total = completed.reduce(0) { $0 + $1.syllableCount }
        return total / completed.count
    }

    // MARK: - Mode

    var showRhymeLabels: Bool { currentMode != .free }
    var showSchemeString: Bool { currentMode != .free }
    var showSections: Bool { currentMode != .free }
    var showStressPatternOption: Bool { currentMode != .free }

    var availableSectionTypes: [SectionType] {
        switch currentMode {
        case .lyrics: return SectionType.allCases
        case .poem:   return [.verse, .bridge, .outro, .intro] // Stanza, Volta, Coda, Opening
        case .free:   return []
        }
    }

    /// Per-line syllable target from the current poem form (e.g., 5-7-5 for haiku).
    func syllableTarget(forLine index: Int) -> Int? {
        guard currentMode == .poem, let pattern = currentPoemForm?.syllablePattern else { return nil }
        guard index < pattern.count else { return nil }
        return pattern[index]
    }

    /// Total line target from the current poem form.
    var poemFormLineTarget: Int? {
        guard currentMode == .poem else { return nil }
        return currentPoemForm?.lineCount
    }

    func switchMode(to mode: EntryMode) {
        guard mode != currentMode else { return }

        // Save current mode's state
        modeSnapshots[currentMode] = ModeSnapshot(
            lines: lines,
            sections: sections,
            rhymeLabels: rhymeLabels,
            schemeString: schemeString,
            currentLineIndex: currentLineIndex,
            poemForm: currentPoemForm
        )

        currentMode = mode

        // Restore saved state for the new mode, or start fresh
        if let snapshot = modeSnapshots[mode] {
            lines = snapshot.lines
            sections = snapshot.sections
            rhymeLabels = snapshot.rhymeLabels
            schemeString = snapshot.schemeString
            currentLineIndex = snapshot.currentLineIndex
            currentPoemForm = snapshot.poemForm
        } else {
            // Fresh state for a mode we haven't visited yet
            lines = [LyricLine()]
            sections = []
            rhymeLabels = [nil]
            schemeString = ""
            currentLineIndex = 0
            currentPoemForm = nil
            undoStack = []
        redoStack = []
        }

        // Clear transient state
        suggestions = []
        suggestionsTargetLabel = nil
        suggestionsTargetWord = nil
        lockedEndWord = nil
        selectedSuggestionIndex = -1

        if mode == .free {
            schemeString = ""
            rhymeLabels = Array(repeating: nil, count: lines.count)
        } else if mode != .poem {
            refreshScheme()
        }

        autoSave()
    }

    /// Whether the current poem form uses a static template (fixed line count).
    var isTemplateMode: Bool {
        currentMode == .poem && (currentPoemForm?.hasTemplate == true)
    }

    func selectPoemForm(_ form: PoemForm?) {
        currentPoemForm = form
        if let form = form, form.hasTemplate {
            generatePoemTemplate(for: form)
        } else if form == nil || form?.hasTemplate == false {
            // Switching away from a fixed form — reset to normal
            if lines.allSatisfy({ $0.text.trimmingCharacters(in: .whitespaces).isEmpty }) {
                lines = [LyricLine()]
                sections = []
                rhymeLabels = [nil]
                schemeString = ""
            }
        }
        autoSave()
    }

    private func generatePoemTemplate(for form: PoemForm) {
        guard let lineCount = form.lineCount else { return }
        let labels = form.rhymeLabelsPerLine
        let stanzaBreaks = Set(form.stanzaBreaks ?? [])

        // Clear existing sections
        sections = []

        // Generate empty lines with pre-assigned labels
        var newLines: [LyricLine] = []
        for i in 0..<lineCount {
            var line = LyricLine()
            if let labels = labels, i < labels.count, let label = labels[i] {
                line.labelOverride = label
            }
            // Assign stanza sections
            if stanzaBreaks.contains(i) {
                let stanzaNumber = (form.stanzaBreaks ?? []).firstIndex(of: i).map { $0 + 1 }
                let section = SectionMarker(type: .verse, number: stanzaNumber)
                sections.append(section)
                line.sectionId = section.id
            } else if !stanzaBreaks.isEmpty, let lastBreak = (form.stanzaBreaks ?? []).last(where: { $0 <= i }) {
                // Assign to the section started at the last stanza break
                let breakIndex = (form.stanzaBreaks ?? []).firstIndex(of: lastBreak)!
                if breakIndex < sections.count {
                    line.sectionId = sections[breakIndex].id
                }
            }
            newLines.append(line)
        }

        lines = newLines

        // Set rhyme labels from template
        if let labels = labels {
            rhymeLabels = labels
        } else {
            rhymeLabels = Array(repeating: nil, count: lineCount)
        }
        schemeString = rhymeLabels.compactMap { $0 }.joined()

        currentLineIndex = 0
        suggestions = []
        lockedEndWord = nil
        undoStack = []
        redoStack = []
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
