import SwiftUI

struct SidebarView: View {
    @ObservedObject var vm: LyricViewModel

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Entries")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Button(action: { vm.newEntry() }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("New entry")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().opacity(0.3)

            // Entry list
            if vm.entries.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("No entries yet")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Start writing to create one")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.3))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.entries) { entry in
                            SidebarEntryRow(
                                entry: entry,
                                isSelected: entry.id == vm.currentEntryId,
                                dateFormatter: dateFormatter,
                                onTap: { vm.loadEntry(entry) },
                                onDelete: { vm.deleteEntry(entry) }
                            )
                        }
                    }
                }
            }
        }
    }
}

struct SidebarEntryRow: View {
    let entry: LyricEntry
    let isSelected: Bool
    let dateFormatter: DateFormatter
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: entry.mode.icon)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(entry.displayTitle)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(dateFormatter.string(from: entry.updatedAt))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))

                    let lineCount = entry.lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.count
                    if lineCount > 0 {
                        Text("\(lineCount) line\(lineCount == 1 ? "" : "s")")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.4))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : (hovered ? Color.secondary.opacity(0.05) : Color.clear))
                    .padding(.horizontal, 8)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .contextMenu {
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}
