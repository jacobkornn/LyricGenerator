import SwiftUI

struct RhymeSuggestionsView: View {
    let suggestions: [RhymeService.RhymeWord]
    let targetLabel: String?
    let targetWord: String?
    var selectedIndex: Int = -1
    let onSelect: (String) -> Void
    @Binding var expanded: Bool

    var body: some View {
        if !suggestions.isEmpty {
            HStack(alignment: .top, spacing: 0) {
                Color.clear.frame(width: 36, height: 1)

                VStack(alignment: .leading, spacing: 6) {
                    // Suggestions in a flow layout, clipped to 1 row when collapsed
                    FlowLayout(spacing: 2) {
                        Text("...")
                            .foregroundColor(.secondary.opacity(0.4))
                            .font(.system(size: 14, weight: .light))

                        ForEach(Array(suggestions.enumerated()), id: \.1.word) { i, rhyme in
                            HStack(spacing: 0) {
                                SuggestionChip(
                                    word: rhyme.word,
                                    syllables: rhyme.numSyllables,
                                    isSelected: i == selectedIndex
                                ) {
                                    onSelect(rhyme.word)
                                }
                                if i < suggestions.count - 1 {
                                    Text(",")
                                        .foregroundColor(.secondary.opacity(0.3))
                                        .font(.system(size: 14))
                                }
                            }
                        }
                    }
                    .frame(maxHeight: expanded ? 200 : 26, alignment: .topLeading)
                    .clipped()

                    // See more / see less + info
                    HStack(spacing: 8) {
                        if suggestions.count > 4 {
                            Button(action: { withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() } }) {
                                Text(expanded ? "see less" : "see more (+\(suggestions.count - 4))")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .stroke(Color.secondary.opacity(0.15))
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        if let word = targetWord, let label = targetLabel {
                            Text("rhymes with \"\(word)\" (\(label))")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.3))
                                .italic()
                                .tracking(0.3)
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
                }
            }
            .padding(.leading, 0)
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
