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
    }
}

private struct LunaCustomTabShell: View {
    @EnvironmentObject private var appState: LunaAppState

    var body: some View {
        NavigationStack {
            appState.selectedTab.destination
        }
        .safeAreaInset(edge: .bottom) {
            LunaFloatingTabBar(selection: $appState.selectedTab)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
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

    var body: some View {
        HStack(spacing: 8) {
            ForEach(LunaTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 24, height: 22)

                        if selection == tab {
                            Text(tab.shortTitle)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundStyle(selection == tab ? Color.accentColor : Color.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.thinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
    }
}
