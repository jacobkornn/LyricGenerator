import SwiftUI

struct PoemFormGuideView: View {
    @ObservedObject var vm: LyricViewModel

    private var form: PoemForm? { vm.currentPoemForm }

    private var contentLineCount: Int {
        vm.lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    var body: some View {
        if let form = form {
            HStack(spacing: 12) {
                // Form name
                Text(form.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange.opacity(0.8))
                    .textCase(.uppercase)
                    .tracking(0.5)

                // Structure hint
                if let pattern = form.syllablePattern {
                    let patternStr = pattern.map { "\($0)" }.joined(separator: "-")
                    Text(patternStr + " syllables")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.4))
                }

                // Line progress
                if let target = form.lineCount {
                    let color: Color = contentLineCount == target ? .green.opacity(0.6) :
                                       contentLineCount > target ? .red.opacity(0.5) :
                                       .secondary.opacity(0.4)
                    Text("\(contentLineCount)/\(target) lines")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(color)
                }

                // Rhyme scheme template
                if let scheme = form.rhymeSchemeTemplate {
                    Text(scheme)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.35))
                }

                Spacer()
            }
        }
    }
}
