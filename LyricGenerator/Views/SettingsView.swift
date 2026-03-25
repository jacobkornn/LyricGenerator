import SwiftUI

struct SettingsToggle: View {
    @Binding var expanded: Bool

    var body: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary.opacity(0.5))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.secondary.opacity(expanded ? 0.12 : 0.06))
                )
        }
        .buttonStyle(.plain)
        .help("Settings")
    }
}

struct SettingsPanel: View {
    @ObservedObject var vm: LyricViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary.opacity(0.7))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Rhyme Sensitivity")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(sensitivityLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange.opacity(0.8))
                }

                Slider(value: $vm.rhymeSensitivity, in: 0...1, step: 0.1)
                    .controlSize(.small)

                HStack {
                    Text("Loose")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.4))
                    Spacer()
                    Text("Strict")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.4))
                }

                Text(sensitivityDescription)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(width: 220)
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

    private var sensitivityLabel: String {
        switch vm.rhymeSensitivity {
        case 0..<0.3: return "Loose"
        case 0.3..<0.6: return "Moderate"
        case 0.6..<0.85: return "Tight"
        default: return "Strict"
        }
    }

    private var sensitivityDescription: String {
        switch vm.rhymeSensitivity {
        case 0..<0.3: return "Near rhymes and similar sounds count. e.g. night / life"
        case 0.3..<0.6: return "Ending sounds must be close. e.g. night / sight"
        case 0.6..<0.85: return "Only strong rhymes. e.g. night / light"
        default: return "Perfect rhymes only. e.g. night / spite"
        }
    }
}
