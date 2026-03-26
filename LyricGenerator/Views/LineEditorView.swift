import SwiftUI
import AppKit

struct LineEditorView: View {
    let index: Int
    let line: LyricLine
    var mode: EntryMode = .lyrics
    let rhymeLabel: String?
    let isActive: Bool
    let lockedEndWord: String?
    let onCommit: () -> Void
    let onTextChange: (String) -> Void
    let onFocus: () -> Void
    var onCancelLocked: (() -> Void)? = nil
    var onBackspaceEmpty: (() -> Void)? = nil
    var onLabelEdit: ((String) -> Void)? = nil
    var targetSyllableCount: Int? = nil
    /// Per-line syllable target from a poem form (e.g., 5 for first haiku line)
    var syllableTarget: Int? = nil
    var showStressPattern: Bool = false
    var onTabSuggestion: (() -> Void)? = nil
    var onArrowDown: (() -> Void)? = nil
    var onArrowUp: (() -> Void)? = nil
    var onEscSuggestion: (() -> Void)? = nil

    @State private var lockedHovered: Bool = false
    @State private var editingLabel: Bool = false
    @State private var editLabelText: String = ""
    @FocusState private var labelFieldFocused: Bool

    private let labelColors: [String: Color] = [
        "A": .orange, "B": .cyan, "C": .purple, "D": .pink,
        "E": .green, "F": .yellow, "G": .mint, "H": .indigo,
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Rhyme label (invisible spacer in free mode to keep alignment)
            if mode == .free {
                Color.clear
                    .frame(width: 24, height: 24)
                    .padding(.top, 4)
            } else {
                ZStack {
                    if editingLabel {
                        let displayLabel = editLabelText.uppercased()
                        let color = labelColors[displayLabel] ?? .gray
                        TextField("", text: $editLabelText)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.center)
                            .foregroundColor(color)
                            .frame(width: 24, height: 24)
                            .background(color.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .focused($labelFieldFocused)
                            .onSubmit { commitLabelEdit() }
                            .onExitCommand { editingLabel = false }
                            .onChange(of: labelFieldFocused) { _, focused in
                                if !focused { commitLabelEdit() }
                            }
                            .onAppear { labelFieldFocused = true }
                    } else if let label = rhymeLabel {
                        Text(label)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(labelColors[label] ?? .gray)
                            .frame(width: 24, height: 24)
                            .background(
                                (labelColors[label] ?? .gray).opacity(0.12)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .onTapGesture(count: 2) {
                                editLabelText = label
                                editingLabel = true
                            }
                    } else {
                        Text(" ")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .frame(width: 24, height: 24)
                            .opacity(0)
                    }
                }
                .frame(width: 24)
                .padding(.top, 4)
            }

            // Text field
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    LyricTextField(
                        text: line.text,
                        isActive: isActive,
                        onTextChange: onTextChange,
                        onEnter: onCommit,
                        onFocus: onFocus,
                        onBackspaceEmpty: onBackspaceEmpty ?? {},
                        onTab: onTabSuggestion ?? {},
                        onArrowDown: onArrowDown ?? {},
                        onArrowUp: onArrowUp ?? {},
                        onEscape: onEscSuggestion ?? {}
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let locked = lockedEndWord, isActive {
                        HStack(spacing: 4) {
                            Text(locked)
                                .font(.custom("EB Garamond", size: 22))
                                .foregroundColor(.secondary.opacity(0.5))
                                .italic()

                            if lockedHovered {
                                Button(action: { onCancelLocked?() }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.leading, 4)
                        .onHover { lockedHovered = $0 }
                        .animation(.easeOut(duration: 0.15), value: lockedHovered)
                    }
                }

                // Info row: syllables + stress pattern
                if mode != .free {
                    HStack(spacing: 8) {
                        // Syllable count & flow indicator
                        if isActive, let locked = lockedEndWord, let target = targetSyllableCount {
                            let lockedSyl = SyllableCounter.countWord(locked)
                            let currentSyl = line.syllableCount
                            let totalSoFar = currentSyl + lockedSyl
                            let remaining = target - totalSoFar
                            HStack(spacing: 6) {
                                Text("\(currentSyl) + \(lockedSyl) syl")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary.opacity(0.35))
                                if remaining > 0 {
                                    Text("~\(remaining) more to match flow")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.orange.opacity(0.6))
                                } else if remaining == 0 {
                                    Text("on target")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.green.opacity(0.6))
                                } else {
                                    Text("\(abs(remaining)) over")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.red.opacity(0.5))
                                }
                            }
                        } else if !line.text.trimmingCharacters(in: .whitespaces).isEmpty {
                            // Show syllable count with form target if available
                            if let target = syllableTarget {
                                let syl = line.syllableCount
                                let color: Color = syl == target ? .green.opacity(0.6) :
                                                   syl > target ? .red.opacity(0.5) :
                                                   .orange.opacity(0.6)
                                Text("\(syl)/\(target) syl")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(color)
                            } else {
                                Text("\(line.syllableCount) syl")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary.opacity(0.35))
                            }
                        }

                        // Stress / beat pattern
                        if showStressPattern && !line.stressPattern.isEmpty && !line.text.trimmingCharacters(in: .whitespaces).isEmpty {
                            StressPatternView(pattern: line.stressPattern)
                        }
                    }
                    .padding(.top, 1)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onFocus()
        }
    }

    private func commitLabelEdit() {
        let newLabel = editLabelText.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !newLabel.isEmpty, newLabel.count == 1, newLabel.first?.isLetter == true {
            onLabelEdit?(newLabel)
        }
        editingLabel = false
    }
}

// MARK: - Stress Pattern Visualization
struct StressPatternView: View {
    let pattern: [Int]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(pattern.enumerated()), id: \.offset) { _, stress in
                Circle()
                    .fill(stress == 1 ? Color.orange.opacity(0.6) : Color.secondary.opacity(0.15))
                    .frame(width: stress == 1 ? 7 : 5, height: stress == 1 ? 7 : 5)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.04))
        )
        .help("Rhythm: large = stressed, small = unstressed")
    }
}

// MARK: - AppKit NSTextField wrapper with proper focus & Enter handling

struct LyricTextField: NSViewRepresentable {
    let text: String
    let isActive: Bool
    let onTextChange: (String) -> Void
    let onEnter: () -> Void
    let onFocus: () -> Void
    let onBackspaceEmpty: () -> Void
    let onTab: () -> Void
    let onArrowDown: () -> Void
    let onArrowUp: () -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> LyricNSTextField {
        let field = LyricNSTextField()
        field.font = NSFont(name: "EB Garamond", size: 22) ?? .systemFont(ofSize: 22)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.lineBreakMode = .byWordWrapping
        field.usesSingleLineMode = false
        field.maximumNumberOfLines = 5
        field.cell?.wraps = true
        field.cell?.isScrollable = false
        field.placeholderString = ""
        field.textColor = .labelColor
        field.stringValue = text
        field.delegate = context.coordinator
        field.coordinator = context.coordinator
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ nsView: LyricNSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        context.coordinator.onTextChange = onTextChange
        context.coordinator.onEnter = onEnter
        context.coordinator.onFocus = onFocus
        context.coordinator.onBackspaceEmpty = onBackspaceEmpty
        context.coordinator.onTab = onTab
        context.coordinator.onArrowDown = onArrowDown
        context.coordinator.onArrowUp = onArrowUp
        context.coordinator.onEscape = onEscape

        let wasActive = context.coordinator.wasActive
        context.coordinator.wasActive = isActive

        if isActive && !wasActive {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
                if let editor = nsView.currentEditor() {
                    editor.selectedRange = NSRange(location: editor.string.count, length: 0)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTextChange: onTextChange, onEnter: onEnter, onFocus: onFocus,
            onBackspaceEmpty: onBackspaceEmpty, onTab: onTab,
            onArrowDown: onArrowDown, onArrowUp: onArrowUp, onEscape: onEscape
        )
    }

    class Coordinator: NSObject, NSTextFieldDelegate, NSControlTextEditingDelegate {
        var onTextChange: (String) -> Void
        var onEnter: () -> Void
        var onFocus: () -> Void
        var onBackspaceEmpty: () -> Void
        var onTab: () -> Void
        var onArrowDown: () -> Void
        var onArrowUp: () -> Void
        var onEscape: () -> Void
        var wasActive: Bool = false

        init(onTextChange: @escaping (String) -> Void, onEnter: @escaping () -> Void,
             onFocus: @escaping () -> Void, onBackspaceEmpty: @escaping () -> Void,
             onTab: @escaping () -> Void, onArrowDown: @escaping () -> Void,
             onArrowUp: @escaping () -> Void, onEscape: @escaping () -> Void) {
            self.onTextChange = onTextChange
            self.onEnter = onEnter
            self.onFocus = onFocus
            self.onBackspaceEmpty = onBackspaceEmpty
            self.onTab = onTab
            self.onArrowDown = onArrowDown
            self.onArrowUp = onArrowUp
            self.onEscape = onEscape
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            onTextChange(field.stringValue)
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            onFocus()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onEnter()
                return true
            }
            if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
                if let field = control as? NSTextField, field.stringValue.isEmpty {
                    onBackspaceEmpty()
                    return true
                }
            }
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                onTab()
                return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                onArrowDown()
                return true
            }
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                onArrowUp()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                onEscape()
                return true
            }
            return false
        }

        func controlTextDidEndEditing(_ obj: Notification) {}
    }
}

class LyricNSTextField: NSTextField {
    weak var coordinator: LyricTextField.Coordinator?
}
