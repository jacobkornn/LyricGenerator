import SwiftUI

struct ThemeToggleView: View {
    @ObservedObject var vm: LyricViewModel

    var body: some View {
        Button(action: { vm.toggleTheme() }) {
            Image(systemName: vm.isDark ? "sun.max" : "moon")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary.opacity(0.5))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.secondary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .help(vm.isDark ? "Switch to light mode" : "Switch to dark mode")
    }
}
