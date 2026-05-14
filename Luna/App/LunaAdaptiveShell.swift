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
        .onChange(of: appState.selectedTab) { _ in
            Haptics.selection()
        }
    }
}

private struct LunaCustomTabShell: View {
    @EnvironmentObject private var appState: LunaAppState
    @State private var isTabBarVisible = true

    var body: some View {
        NavigationStack {
            appState.selectedTab.destination
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if isTabBarVisible {
                    LunaFloatingTabBar(
                        selection: $appState.selectedTab,
                        closeAction: closeTabBar
                    )
                    .padding(.horizontal, 18)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    LunaTabBarRevealButton(action: revealTabBar)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: isTabBarVisible)
        }
    }

    private func closeTabBar() {
        Haptics.selection()
        isTabBarVisible = false
    }

    private func revealTabBar() {
        Haptics.selection()
        isTabBarVisible = true
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
    let closeAction: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(LunaTab.allCases) { tab in
                Button {
                    Haptics.selection()
                    selection = tab
                } label: {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 42)
                        .foregroundStyle(selection == tab ? Color.accentColor : Color.secondary)
                        .background {
                            if selection == tab {
                                Capsule(style: .continuous)
                                    .fill(Color.accentColor.opacity(0.16))
                            }
                        }
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }

            Divider()
                .frame(height: 26)
                .padding(.horizontal, 2)

            Button(action: closeAction) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 38, height: 42)
                    .foregroundStyle(Color.secondary)
                    .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide tab bar")
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 20, x: 0, y: 10)
    }
}

private struct LunaTabBarRevealButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.up")
                .font(.system(size: 15, weight: .bold))
                .frame(width: 48, height: 42)
                .foregroundStyle(Color.secondary)
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show tab bar")
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
