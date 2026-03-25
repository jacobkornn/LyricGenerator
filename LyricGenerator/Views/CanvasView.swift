import SwiftUI

struct CanvasView: View {
    @ObservedObject var vm: LyricViewModel

    // Line text starts at: 24 (label width) + 12 (HStack spacing) = 36pt from VStack edge
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
                        .padding(.bottom, 20)
                        .onSubmit { vm.autoSave() }

                    // Scheme display
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
                        .padding(.leading, textLeading)
                        .padding(.bottom, 16)
                    }

                    // Lines
                    ForEach(Array(vm.lines.enumerated()), id: \.1.id) { index, line in
                        VStack(alignment: .leading, spacing: 0) {
                            LineEditorView(
                                index: index,
                                line: line,
                                rhymeLabel: index != vm.currentLineIndex ? (vm.rhymeLabels[safe: index] ?? nil) : nil,
                                isActive: index == vm.currentLineIndex,
                                lockedEndWord: index == vm.currentLineIndex ? vm.lockedEndWord : nil,
                                onCommit: { vm.commitLine(at: index) },
                                onTextChange: { text in vm.updateLineText(at: index, text: text) },
                                onFocus: { vm.currentLineIndex = index },
                                onCancelLocked: { vm.clearLockedWord() },
                                onBackspaceEmpty: { vm.deleteEmptyLine(at: index) },
                                onLabelEdit: { newLabel in vm.overrideLabel(at: index, to: newLabel) },
                                targetSyllableCount: index == vm.currentLineIndex ? vm.averageSyllableCount : nil
                            )
                            .id(line.id)

                            // Show suggestions under the active (current) line
                            if index == vm.currentLineIndex && !vm.suggestions.isEmpty {
                                RhymeSuggestionsView(
                                    suggestions: vm.suggestions,
                                    targetLabel: vm.suggestionsTargetLabel,
                                    targetWord: vm.suggestionsTargetWord,
                                    onSelect: { word in vm.selectSuggestion(word) }
                                )
                                .padding(.top, 2)
                                .padding(.bottom, 4)
                            }
                        }
                    }

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
