import SwiftUI

struct LunaAdaptiveShell: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
#if os(macOS)
        LunaSidebarShell()
#else
        if horizontalSizeClass == .regular {
            LunaSidebarShell()
        } else {
            if #available(iOS 26.0, *) {
                LunaNativeTabShell()
            } else {
                LunaCustomTabShell()
            }
        }
#endif
    }
}

private struct LunaNativeTabShell: View {
    @EnvironmentObject private var appState: LunaAppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ForEach(LunaTab.allCases) { tab in
                NavigationStack {
                    tab.destination
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
        }
        .tabBarMinimizeIfAvailable()
        .guidedTourOverlay(appState: appState)
        .onChange(of: appState.selectedTab) { _ in
            Haptics.selection()
        }
    }
}

private struct LunaCustomTabShell: View {
    @EnvironmentObject private var appState: LunaAppState
    @State private var isTabBarExpanded = true

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ForEach(LunaTab.allCases) { tab in
                NavigationStack {
                    tab.destination
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .tag(tab)
                .toolbar(.hidden, for: .tabBar)
            }
        }
        .lunaCustomTabBarBottomReserve()
        .overlay(alignment: .bottom) {
            LunaFloatingTabBar(
                selection: $appState.selectedTab,
                isExpanded: $isTabBarExpanded
            )
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .guidedTourOverlay(appState: appState)
    }
}

struct LunaSidebarShell: View {
    @EnvironmentObject private var appState: LunaAppState

    var body: some View {
        NavigationSplitView {
#if os(macOS)
            List(selection: $appState.selectedTab) {
                Section("Explore") {
                    ForEach(LunaTab.primaryTabs) { tab in
                        Label(tab.title, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                }

                Section("App") {
                    Label(LunaTab.settings.title, systemImage: LunaTab.settings.systemImage)
                        .tag(LunaTab.settings)
                }
            }
            .navigationTitle("Luna")
#else
            List {
                Section("Explore") {
                    ForEach(LunaTab.primaryTabs) { tab in
                        LunaSidebarButton(tab: tab, selection: $appState.selectedTab)
                    }
                }

                Section("App") {
                    LunaSidebarButton(tab: .settings, selection: $appState.selectedTab)
                }
            }
            .navigationTitle("Luna")
#endif
        } detail: {
            NavigationStack {
                appState.selectedTab.destination
            }
        }
        .guidedTourOverlay(appState: appState)
    }
}

private struct LunaSidebarButton: View {
    let tab: LunaTab
    @Binding var selection: LunaTab

    var body: some View {
        Button {
            Haptics.selection()
            selection = tab
        } label: {
            Label(tab.title, systemImage: tab.systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selection == tab ? Color.accentColor : Color.primary)
    }
}

private struct LunaFloatingTabBar: View {
    @Binding var selection: LunaTab
    @Binding var isExpanded: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isExpanded {
                ForEach(LunaTab.allCases) { tab in
                    Button {
                        Haptics.selection()
                        selection = tab
                    } label: {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 19, weight: .semibold))
                            .frame(width: itemSize, height: itemSize)
                            .foregroundStyle(selection == tab ? Color.accentColor : Color.secondary)
                            .background {
                                if selection == tab {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.16))
                                }
                            }
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(selection == tab ? .isSelected : [])
                }

                Divider()
                    .frame(height: 28)
                    .padding(.horizontal, 2)
            }

            Button(action: toggleExpanded) {
                Image(systemName: isExpanded ? "arrow.right" : "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: itemSize)
                    .foregroundStyle(Color.secondary)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse tab bar" : "Expand tab bar")
        }
        .padding(6)
        .frame(width: isExpanded ? expandedWidth : collapsedSize, height: collapsedSize, alignment: .trailing)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 20, x: 0, y: 10)
        .clipShape(Capsule(style: .continuous))
        .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.78, blendDuration: 0.16), value: isExpanded)
        .frame(width: expandedWidth, alignment: .trailing)
    }

    private func toggleExpanded() {
        Haptics.selection()
        withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.74, blendDuration: 0.16)) {
            isExpanded.toggle()
        }
    }

    private var expandedWidth: CGFloat {
        CGFloat(LunaTab.allCases.count) * (itemSize + 6) + 62
    }

    private var itemSize: CGFloat {
        46
    }

    private var collapsedSize: CGFloat {
        50
    }
}

private extension View {
    @ViewBuilder
    func tabBarMinimizeIfAvailable() -> some View {
#if os(iOS)
        if #available(iOS 26.0, *) {
            self
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabBarMinimizeBehavior(.onScrollUp)
        } else {
            self
        }
#else
        self
#endif
    }
}
