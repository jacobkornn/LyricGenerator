import SwiftUI

struct ContentView: View {
    @StateObject private var vm = LyricViewModel()
    @State private var sidebarVisible = true
    @State private var settingsExpanded = false

    var body: some View {
        NavigationSplitView(
            columnVisibility: .init(get: {
                sidebarVisible ? .doubleColumn : .detailOnly
            }, set: { visibility in
                sidebarVisible = visibility != .detailOnly
            })
        ) {
            SidebarView(vm: vm)
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
        } detail: {
            ZStack(alignment: .topTrailing) {
                CanvasView(vm: vm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Top-right: icon bar + floating panels
                VStack(alignment: .trailing, spacing: 6) {
                    // Icon bar — fixed, never moves
                    HStack(spacing: 8) {
                        SettingsToggle(expanded: $settingsExpanded)
                        WordBankToggle(vm: vm)
                        ThemeToggleView(vm: vm)

                        Button(action: { sidebarVisible.toggle() }) {
                            Image(systemName: "sidebar.left")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.5))
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(Color.secondary.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Toggle sidebar")
                    }
                    .zIndex(1) // Icons always on top of panels

                    // Panels float below, outside the icon layout
                    if settingsExpanded {
                        SettingsPanel(vm: vm)
                    }
                    if vm.wordBankExpanded {
                        WordBankPanel(vm: vm)
                    }
                }
                .padding(16)
            }
        }
        .preferredColorScheme(vm.isDark ? .dark : .light)
        .onKeyPress(keys: [.init("z")], phases: .down) { press in
            if press.modifiers.contains(.command) {
                vm.undo()
                return .handled
            }
            return .ignored
        }
    }
}
