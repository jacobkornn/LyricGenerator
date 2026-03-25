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

                    // Scheme display + structure summary
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

                        if !vm.sections.isEmpty {
                            Text(vm.sections.map { $0.displayName }.joined(separator: " → "))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.3))
                                .italic()
                        }

                        Spacer()
                    }
                    .padding(.leading, textLeading)
                    .padding(.bottom, 16)

                    // Section add button
                    SectionPicker { type in
                        vm.addSection(type)
                    }
                    .padding(.leading, textLeading)
                    .padding(.bottom, 8)

                    // Lines
                    ForEach(Array(vm.lines.enumerated()), id: \.1.id) { index, line in
                        VStack(alignment: .leading, spacing: 0) {
                            // Section header if this line starts a new section
                            if let section = vm.sectionForLine(at: index),
                               (index == 0 || vm.lines[index - 1].sectionId != line.sectionId) {
                                SectionHeaderView(
                                    section: section,
                                    onRemove: {
                                        if let idx = vm.sections.firstIndex(where: { $0.id == section.id }) {
                                            vm.removeSection(at: idx)
                                        }
                                    }
                                )
                                .padding(.bottom, 20)
                                .padding(.top, index == 0 ? 8 : 36)
                            }

                            // Drop zone indicator for dragging sections between lines
                            SectionDropZone(lineIndex: index, vm: vm)

                            LineEditorView(
                                index: index,
                                line: line,
                                rhymeLabel: vm.rhymeLabels[safe: index] ?? nil,
                                isActive: index == vm.currentLineIndex,
                                lockedEndWord: index == vm.currentLineIndex ? vm.lockedEndWord : nil,
                                onCommit: { vm.commitLine(at: index) },
                                onTextChange: { text in vm.updateLineText(at: index, text: text) },
                                onFocus: { vm.currentLineIndex = index },
                                onCancelLocked: { vm.clearLockedWord() },
                                onBackspaceEmpty: { vm.deleteEmptyLine(at: index) },
                                onLabelEdit: { newLabel in vm.overrideLabel(at: index, to: newLabel) },
                                targetSyllableCount: index == vm.currentLineIndex ? vm.averageSyllableCount : nil,
                                showStressPattern: vm.showFlowPattern,
                                onTabSuggestion: { vm.confirmSelectedSuggestion() },
                                onArrowDown: { vm.selectNextSuggestion() },
                                onArrowUp: { vm.selectPreviousSuggestion() },
                                onEscSuggestion: { vm.dismissSuggestions() }
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
                                        expanded: $vm.suggestionsExpanded
                                    )
                                    .padding(.top, 2)
                                    .padding(.bottom, 4)
                                }
                            }
                        }
                    }

                    // Drop zone after last line for dragging sections to bottom
                    SectionDropZone(lineIndex: vm.lines.count - 1, vm: vm)

                    Spacer(minLength: 200)
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
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
    let onSelect: (SectionType) -> Void
    @State private var isExpanded = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: { withAnimation(.easeOut(duration: 0.15)) { isExpanded.toggle() } }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium))
                    Text("Section")
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
                ForEach(SectionType.allCases, id: \.self) { type in
                    Button(action: {
                        onSelect(type)
                        withAnimation(.easeOut(duration: 0.15)) { isExpanded = false }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: type.icon)
                                .font(.system(size: 9))
                            Text(type.rawValue)
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
    @State private var hovered = false

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

                Text(section.displayName)
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
        .draggable(section.id.uuidString)
    }
}

// MARK: - Drop Zone (only expands during drag)
struct SectionDropZone: View {
    let lineIndex: Int
    @ObservedObject var vm: LyricViewModel
    @State private var isTargeted = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(isTargeted ? Color.orange.opacity(0.25) : Color.clear)
            .frame(height: isTargeted ? 28 : 0)
            .frame(maxWidth: .infinity)
            .animation(.easeOut(duration: 0.15), value: isTargeted)
            .dropDestination(for: String.self) { items, _ in
                guard let uuidString = items.first, let sectionId = UUID(uuidString: uuidString) else { return false }
                vm.moveSection(sectionId: sectionId, toLineIndex: lineIndex)
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }
    }
}
