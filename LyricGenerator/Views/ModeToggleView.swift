import SwiftUI

struct ModeToggleView: View {
    @ObservedObject var vm: LyricViewModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(EntryMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        vm.switchMode(to: mode)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 10, weight: .medium))
                        Text(mode.displayName)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(vm.currentMode == mode ? .primary : .secondary.opacity(0.5))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(vm.currentMode == mode ? Color.primary.opacity(0.08) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }
}
