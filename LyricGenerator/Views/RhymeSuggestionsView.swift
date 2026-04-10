import SwiftUI

struct RhymeSuggestionsView: View {
    let suggestions: [RhymeService.RhymeWord]
    let targetLabel: String?
    let targetWord: String?
    var selectedIndex: Int = -1
    let onSelect: (String) -> Void
    @Binding var expanded: Bool
    var availableLabels: [String] = []
    var onSwitchLabel: ((String?) -> Void)? = nil

    private var visibleSuggestions: [RhymeService.RhymeWord] {
        expanded ? suggestions : Array(suggestions.prefix(8))
    }

    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 12) {
                    // +/- toggle aligned with rhyme labels
                    if suggestions.count > 8 {
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() }
                        }) {
                            Image(systemName: expanded ? "minus" : "plus")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.5))
                                .frame(width: 24, height: 24)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .help(expanded ? "Show fewer suggestions" : "Show more suggestions")
                    } else {
                        Color.clear.frame(width: 24, height: 24)
                    }

                    // Suggestions
                    FlowLayout(spacing: 2) {
                        Text("...")
                            .foregroundColor(.secondary.opacity(0.4))
                            .font(.system(size: 14, weight: .light))

                        ForEach(Array(visibleSuggestions.enumerated()), id: \.1.word) { i, rhyme in
                            HStack(spacing: 0) {
                                SuggestionChip(
                                    word: rhyme.word,
                                    syllables: rhyme.numSyllables,
                                    isSelected: i == selectedIndex
                                ) {
                                    onSelect(rhyme.word)
                                }
                                if i < visibleSuggestions.count - 1 {
                                    Text(",")
                                        .foregroundColor(.secondary.opacity(0.3))
                                        .font(.system(size: 14))
                                }
                            }
                        }
                    }
                }

                // Info row
                HStack(spacing: 8) {
                    if let word = targetWord, let label = targetLabel {
                        Text("rhymes with \"\(word)\"")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.3))
                            .italic()
                            .tracking(0.3)

                        // Label switcher
                        if availableLabels.count > 1, let onSwitch = onSwitchLabel {
                            SuggestionLabelPicker(
                                currentLabel: label,
                                labels: availableLabels,
                                onSwitch: onSwitch
                            )
                        } else {
                            Text("(\(label))")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.3))
                                .italic()
                        }
                    } else if let word = targetWord {
                        Text("rhymes with \"\(word)\"")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.3))
                            .italic()
                            .tracking(0.3)
                    }

                    Text("Tab · ↑↓ · Esc")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.2))
                }
                .padding(.leading, 36)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

struct SuggestionChip: View {
    let word: String
    let syllables: Int?
    var isSelected: Bool = false
    let onTap: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 3) {
                Text(word)
                    .font(.system(size: 14, weight: isSelected ? .medium : .light))
                if let syl = syllables {
                    Text("\(syl)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.3))
                        .superscript()
                }
            }
            .foregroundColor(isSelected ? .primary : (hovered ? .primary : .secondary.opacity(0.55)))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.orange.opacity(0.15) : (hovered ? Color.secondary.opacity(0.08) : Color.clear))
            )
            .overlay(
                isSelected ?
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                : nil
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// Simple superscript modifier
extension View {
    func superscript() -> some View {
        self.baselineOffset(6).font(.system(size: 9))
    }
}

// Simple flow layout for wrapping content
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

// MARK: - Label picker for switching which rhyme label suggestions target

struct SuggestionLabelPicker: View {
    let currentLabel: String
    let labels: [String]
    let onSwitch: (String?) -> Void

    private static let labelColors: [String: Color] = [
        "A": .orange, "B": .cyan, "C": .purple, "D": .pink,
        "E": .green, "F": .yellow, "G": .mint, "H": .indigo,
    ]

    private var color: Color {
        Self.labelColors[currentLabel] ?? .gray
    }

    var body: some View {
        Menu {
            ForEach(labels, id: \.self) { label in
                Button {
                    onSwitch(label == currentLabel ? nil : label)
                } label: {
                    HStack {
                        Text(label)
                        if label == currentLabel {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(currentLabel)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color.opacity(0.9))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(color.opacity(0.25), lineWidth: 0.5)
                )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
