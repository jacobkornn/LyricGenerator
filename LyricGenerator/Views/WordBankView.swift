import SwiftUI

/// The dropdown panel — positioned below the controls row
struct WordBankPanel: View {
    @ObservedObject var vm: LyricViewModel
    @State private var newWord: String = ""
    @State private var hoveredWord: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Input field
            HStack(spacing: 6) {
                TextField("Add a word...", text: $newWord)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity)
                    .onSubmit {
                        addWord()
                    }

                Button(action: addWord) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(newWord.isEmpty ? .secondary.opacity(0.2) : .accentColor.opacity(0.7))
                }
                .buttonStyle(.plain)
                .disabled(newWord.isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.06))
            )

            // Word chips
            if vm.wordBank.isEmpty {
                Text("Add words to inspire your writing")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                FlowLayout(spacing: 4) {
                    ForEach(vm.wordBank, id: \.self) { word in
                        WordBankChip(
                            word: word,
                            isHovered: hoveredWord == word,
                            onHover: { hoveredWord = $0 ? word : nil },
                            onDelete: { vm.removeFromWordBank(word) }
                        )
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.1))
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
    }

    private func addWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let words = trimmed.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for w in words where !w.isEmpty {
            vm.addToWordBank(w)
        }
        newWord = ""
    }
}

struct WordBankChip: View {
    let word: String
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 3) {
            Text(word)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary.opacity(0.7))

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.secondary.opacity(isHovered ? 0.12 : 0.07))
        )
        .onHover { onHover($0) }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}
