import SwiftUI
import AppKit

struct AbletonShortcutButton: View {
    @ObservedObject var vm: LyricViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            PanelIconButton(
                icon: "folder",
                isActive: vm.isAbletonPanelVisible,
                help: "Ableton Projects"
            ) {
                vm.isAbletonPanelVisible.toggle()
                if vm.isAbletonPanelVisible {
                    Task { await vm.scanForAbletonProjects() }
                }
            }

            if vm.isAbletonPanelVisible {
                AbletonProjectPanel(vm: vm)
            }
        }
    }
}

private struct AbletonProjectPanel: View {
    @ObservedObject var vm: LyricViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if vm.isScanningAbleton {
                ProgressView()
                    .controlSize(.small)
                    .padding(8)
            } else if vm.abletonProjects.isEmpty {
                Text("No matches")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.4))
                    .padding(8)
            } else {
                ForEach(vm.abletonProjects) { project in
                    AbletonProjectRow(project: project)
                }
            }

            Divider().opacity(0.2)

            Button {
                Task {
                    _ = await AbletonScanService.chooseDirectory()
                    await vm.scanForAbletonProjects()
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 9))
                    Text("Change folder…")
                        .font(.system(size: 10))
                }
                .foregroundColor(.secondary.opacity(0.45))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.1))
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
}

private struct AbletonProjectRow: View {
    let project: AbletonProject
    @State private var hovered = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(project.url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.45))

                Text(project.name)
                    .font(.system(size: 11))
                    .foregroundColor(.primary.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(hovered ? Color.secondary.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.selectFile(
                    project.url.path,
                    inFileViewerRootedAtPath: project.url.deletingLastPathComponent().path
                )
            }
        }
    }
}
