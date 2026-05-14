import SwiftUI

@main
struct LunaApp: App {
    @StateObject private var appState = LunaAppState()

    var body: some Scene {
        WindowGroup {
            LunaRootView()
                .environmentObject(appState)
        }
    }
}

final class LunaAppState: ObservableObject {
    @Published var selectedTab: LunaTab = .home
}
