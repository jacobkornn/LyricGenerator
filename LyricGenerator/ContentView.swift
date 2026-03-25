import SwiftUI

enum ActivePanel: Equatable {
    case none, settings, wordBank, export, rhymeMap
}

struct ContentView: View {
    @StateObject private var vm = LyricViewModel()
    @State private var sidebarVisible = true
    @State private var activePanel: ActivePanel = .none

    private func toggle(_ panel: ActivePanel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            activePanel = activePanel == panel ? .none : panel
        }
    }

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

                // Top-right: icon bar + single floating panel
                VStack(alignment: .trailing, spacing: 6) {
                    // Icon bar — fixed, never moves
                    HStack(spacing: 8) {
                        PanelIconButton(
                            icon: "square.and.arrow.up",
                            isActive: activePanel == .export,
                            help: "Export"
                        ) { toggle(.export) }

                        PanelIconButton(
                            icon: "point.3.connected.trianglepath.dotted",
                            isActive: activePanel == .rhymeMap,
                            help: "Rhyme Map"
                        ) { toggle(.rhymeMap) }

                        PanelIconButton(
                            icon: "slider.horizontal.3",
                            isActive: activePanel == .settings,
                            help: "Settings"
                        ) { toggle(.settings) }

                        PanelIconButton(
                            icon: "tray.full",
                            isActive: activePanel == .wordBank,
                            help: "Word Bank",
                            badge: vm.wordBank.isEmpty ? nil : vm.wordBank.count
                        ) { toggle(.wordBank) }

                        ThemeToggleView(vm: vm)
                    }
                    .zIndex(1)

                    // Single panel area — fixed width so icons don't shift
                    Group {
                        switch activePanel {
                        case .settings:
                            SettingsPanel(vm: vm)
                        case .wordBank:
                            WordBankPanel(vm: vm)
                        case .export:
                            ExportPanel(vm: vm, isShowing: Binding(
                                get: { activePanel == .export },
                                set: { if !$0 { activePanel = .none } }
                            ))
                        case .rhymeMap:
                            RhymeMapPanel(vm: vm)
                        case .none:
                            EmptyView()
                        }
                    }
                    .frame(width: 260, alignment: .trailing)
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

/// Reusable icon button for the toolbar
struct PanelIconButton: View {
    let icon: String
    let isActive: Bool
    let help: String
    var badge: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(isActive ? 0.12 : 0.06))
                    )

                if let badge = badge {
                    Text("\(badge)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.orange.opacity(0.8)))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
