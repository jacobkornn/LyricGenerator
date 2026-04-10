import SwiftUI

struct CanvasView: View {
    @ObservedObject var vm: LyricViewModel

    private let textLeading: CGFloat = 36

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Title input
                    TextField("Title", text: $vm.customTitle)
                        .font(.custom("EB Garamond", size: 28).weight(.medium))
                        .textFieldStyle(.plain)
                        .foregroundColor(.primary.opacity(vm.customTitle.isEmpty ? 0.25 : 0.85))
                        .padding(.leading, textLeading)
                        .padding(.bottom, 12)
                        .onSubmit { vm.autoSave() }

                    // Poem form picker (poem mode only)
                    if vm.currentMode == .poem {
                        PoemFormPicker(vm: vm)
                            .padding(.leading, textLeading)
                            .padding(.bottom, 8)
                    }

                    // Poem form guide (poem mode with form selected)
                    if vm.currentMode == .poem && vm.currentPoemForm != nil {
                        PoemFormGuideView(vm: vm)
                            .padding(.leading, textLeading)
                            .padding(.bottom, 12)
                    }

                    // Scheme display + structure summary (lyrics & poem only, hidden during multi-select)
                    if vm.showSchemeString && !vm.hasMultiLineSelection {
                        HStack(spacing: 12) {
                            if !vm.schemeString.isEmpty {
                                HStack(spacing: 4) {
                                    Text("Scheme:")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary.opacity(0.35))
                                        .textCase(.uppercase)
                                        .tracking(0.5)
                                    Text(vm.schemeString)
                                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                            }

                            if vm.showSections && !vm.sections.isEmpty {
                                Text(vm.sections.map { $0.type.displayName(for: vm.currentMode) }.joined(separator: " \u{2192} "))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary.opacity(0.3))
                                    .italic()
                            }

                            Spacer()
                        }
                        .padding(.leading, textLeading)
                        .padding(.bottom, 16)
                    }

                    // Section add button (lyrics & poem only)
                    if vm.showSections {
                        SectionPicker(types: vm.availableSectionTypes, mode: vm.currentMode) { type in
                            vm.addSection(type)
                        }
                        .padding(.leading, textLeading)
                        .padding(.bottom, 8)
                    }

                    // Drop zone before first line (for dragging sections to top)
                    if vm.showSections {
                        SectionDropZone(lineIndex: 0, vm: vm, isTopZone: true)
                            .zIndex(1)
                    }

                    // Lines
                    ForEach(Array(vm.lines.enumerated()), id: \.1.id) { index, line in
                        VStack(alignment: .leading, spacing: 0) {
                            // Section header if this line starts a new section (lyrics & poem only)
                            if vm.showSections,
                               let section = vm.sectionForLine(at: index),
                               (index == 0 || vm.lines[index - 1].sectionId != line.sectionId) {
                                SectionHeaderView(
                                    section: section,
                                    onRemove: {
                                        if let idx = vm.sections.firstIndex(where: { $0.id == section.id }) {
                                            vm.removeSection(at: idx)
                                        }
                                    },
                                    vm: vm
                                )
                                .padding(.bottom, 20)
                                .padding(.top, index == 0 ? 8 : 36)
                            }

                            // Drop zone indicator for dragging sections between lines
                            if vm.showSections {
                                SectionDropZone(lineIndex: index, vm: vm)
                            }

                            LineEditorView(
                                index: index,
                                line: line,
                                mode: vm.currentMode,
                                rhymeLabel: vm.showRhymeLabels ? (vm.rhymeLabels[safe: index] ?? nil) : nil,
                                isActive: index == vm.currentLineIndex,
                                isSelected: vm.selectedLines.contains(index),
                                hasMultiLineSelection: vm.hasMultiLineSelection,
                                lockedEndWord: (vm.currentMode != .free && index == vm.currentLineIndex) ? vm.lockedEndWord : nil,
                                onCommit: { vm.commitLine(at: index) },
                                onTextChange: { text in
                                    vm.clearMultiLineSelection()
                                    vm.updateLineText(at: index, text: text)
                                },
                                onFocus: {
                                vm.clearMultiLineSelection()
                                vm.currentLineIndex = index
                            },
                                onCancelLocked: { vm.clearLockedWord() },
                                onBackspaceEmpty: { vm.deleteEmptyLine(at: index) },
                                onLabelEdit: vm.showRhymeLabels ? { newLabel in vm.overrideLabel(at: index, to: newLabel) } : nil,
                                targetSyllableCount: index == vm.currentLineIndex ? (vm.syllableTarget(forLine: index) ?? vm.averageSyllableCount) : nil,
                                syllableTarget: vm.syllableTarget(forLine: index),
                                showStressPattern: vm.showStressPatternOption && vm.showFlowPattern,
                                onTabSuggestion: { vm.confirmSelectedSuggestion() },
                                onArrowDown: { vm.selectNextSuggestion() },
                                onArrowUp: { vm.selectPreviousSuggestion() },
                                onEscSuggestion: { vm.dismissSuggestions() },
                                onSelectAll: { vm.selectAllLines() }
                            )
                            .id(line.id)

                            // Show suggestions under the active line
                            if index == vm.currentLineIndex {
                                if vm.isLoadingSuggestions {
                                    // Loading shimmer
                                    HStack(spacing: 0) {
                                        Color.clear.frame(width: 36, height: 1)
                                        HStack(spacing: 8) {
                                            Text("...")
                                                .foregroundColor(.secondary.opacity(0.3))
                                                .font(.system(size: 14, weight: .light))
                                            ForEach(0..<3, id: \.self) { _ in
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.secondary.opacity(0.08))
                                                    .frame(width: CGFloat.random(in: 40...70), height: 20)
                                            }
                                        }
                                    }
                                    .padding(.top, 2)
                                    .padding(.bottom, 4)
                                    .transition(.opacity)
                                } else if !vm.suggestions.isEmpty {
                                    RhymeSuggestionsView(
                                        suggestions: vm.suggestions,
                                        targetLabel: vm.suggestionsTargetLabel,
                                        targetWord: vm.suggestionsTargetWord,
                                        selectedIndex: vm.selectedSuggestionIndex,
                                        onSelect: { word in vm.selectSuggestion(word) },
                                        expanded: $vm.suggestionsExpanded,
                                        availableLabels: vm.currentMode != .free ? vm.availableRhymeLabels : [],
                                        onSwitchLabel: vm.currentMode != .free ? { label in vm.switchSuggestionLabel(to: label) } : nil
                                    )
                                    .padding(.top, 2)
                                    .padding(.bottom, 4)
                                }
                            }
                        }
                    }

                    // Drop zone after last line for dragging sections to bottom
                    if vm.showSections {
                        SectionDropZone(lineIndex: vm.lines.count - 1, vm: vm)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 80)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            // Catch-all: clear drag state when drop lands outside a zone or is cancelled
            .dropDestination(for: String.self) { _, _ in
                vm.isDraggingSection = false
                return false
            } isTargeted: { targeted in
                if !targeted { vm.isDraggingSection = false }
            }
            .onChange(of: vm.currentLineIndex) { _, newIndex in
                if let lineId = vm.lines[safe: newIndex]?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lineId, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - Section Picker (add section button)
struct SectionPicker: View {
    var types: [SectionType] = SectionType.allCases
    var mode: EntryMode = .lyrics
    let onSelect: (SectionType) -> Void
    @State private var isExpanded = false

    private var label: String {
        mode == .poem ? "Stanza" : "Section"
    }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: { withAnimation(.easeOut(duration: 0.15)) { isExpanded.toggle() } }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium))
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary.opacity(0.4))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .stroke(Color.secondary.opacity(0.15))
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(types, id: \.self) { type in
                    Button(action: {
                        onSelect(type)
                        withAnimation(.easeOut(duration: 0.15)) { isExpanded = false }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: type.icon)
                                .font(.system(size: 9))
                            Text(type.displayName(for: mode))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Section Header (draggable)
struct SectionHeaderView: View {
    let section: SectionMarker
    let onRemove: () -> Void
    @ObservedObject var vm: LyricViewModel
    @State private var hovered = false

    private var modeAwareDisplayName: String {
        let typeName = section.type.displayName(for: vm.currentMode)
        if let number = section.number {
            return "\(typeName) \(number)"
        }
        return typeName
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.secondary.opacity(0.08))
                .frame(height: 1)

            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary.opacity(hovered ? 0.4 : 0.15))

                Image(systemName: section.type.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange.opacity(0.7))

                Text(modeAwareDisplayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1)

                if hovered {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)

            Rectangle()
                .fill(Color.secondary.opacity(0.08))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity)
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.15), value: hovered)
        .onDrag {
            vm.isDraggingSection = true
            return NSItemProvider(object: section.id.uuidString as NSString)
        }
    }
}

// MARK: - Drop Zone (expands during drag for easy targeting)
struct SectionDropZone: View {
    let lineIndex: Int
    @ObservedObject var vm: LyricViewModel
    var isTopZone: Bool = false
    @State private var isTargeted = false

    private var isDragging: Bool { vm.isDraggingSection }

    var body: some View {
        // Visible indicator when targeted
        RoundedRectangle(cornerRadius: 2)
            .fill(isTargeted ? Color.orange.opacity(0.25) : Color.clear)
            .frame(height: isTargeted ? 28 : (isDragging ? (isTopZone ? 20 : 8) : 0))
            .frame(maxWidth: .infinity)
            // Generous invisible padding extends hit area during drag
            .padding(.vertical, isDragging ? (isTopZone ? 16 : 10) : 0)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.15), value: isTargeted)
            .animation(.easeOut(duration: 0.2), value: isDragging)
            .dropDestination(for: String.self) { items, _ in
                guard let uuidString = items.first, let sectionId = UUID(uuidString: uuidString) else { return false }
                vm.moveSection(sectionId: sectionId, toLineIndex: lineIndex)
                vm.isDraggingSection = false
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }
    }
}
