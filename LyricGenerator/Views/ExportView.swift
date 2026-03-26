import SwiftUI
import AppKit

struct ExportPanel: View {
    @ObservedObject var vm: LyricViewModel
    @Binding var isShowing: Bool
    @State private var exportResult: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary.opacity(0.7))

            // Export options
            VStack(spacing: 6) {
                ExportButton(
                    icon: "doc.plaintext",
                    title: "Plain Text",
                    subtitle: vm.currentMode == .free ? "Clean text" : "Clean \(vm.currentMode.displayName.lowercased()) with section markers"
                ) {
                    exportPlainText()
                }

                if vm.currentMode != .free {
                    ExportButton(
                        icon: "doc.richtext",
                        title: "Annotated",
                        subtitle: "With rhyme scheme, syllables & structure"
                    ) {
                        exportAnnotated()
                    }
                }

                ExportButton(
                    icon: "doc.on.clipboard",
                    title: "Copy to Clipboard",
                    subtitle: "Plain text copied to clipboard"
                ) {
                    copyToClipboard()
                }
            }

            if let result = exportResult {
                Text(result)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.green.opacity(0.7))
                    .transition(.opacity)
            }
        }
        .padding(14)
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

    private var baseFilename: String {
        vm.customTitle.isEmpty ? vm.currentMode.displayName.lowercased() : vm.customTitle
    }

    private func exportPlainText() {
        let content = vm.exportPlainText()
        saveToFile(content: content, filename: "\(baseFilename).txt")
    }

    private func exportAnnotated() {
        let content = vm.exportAnnotated()
        saveToFile(content: content, filename: "\(baseFilename)_annotated.txt")
    }

    private func copyToClipboard() {
        let content = vm.exportPlainText()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        withAnimation {
            exportResult = "Copied!"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { exportResult = nil }
        }
    }

    private func saveToFile(content: String, filename: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    DispatchQueue.main.async {
                        withAnimation { exportResult = "Saved!" }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { exportResult = nil }
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        withAnimation { exportResult = "Error saving file" }
                    }
                }
            }
        }
    }
}

struct ExportButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.6))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary.opacity(0.7))
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.4))
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovered ? Color.secondary.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
