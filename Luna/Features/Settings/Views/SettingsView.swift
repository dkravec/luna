import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: LunaAppState
    @State private var isShowingResetConfirmation = false
    @State private var isShowingAPODCacheClearConfirmation = false
    @State private var apodCacheStatusMessage: String?

    private let imageOfTheDayRepository: NASAImageOfTheDayRepositoryProviding = NASAImageOfTheDayRepository()

    private enum ScrollAnchor {
        static let replayTour = "settings.replayTour"
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    PageHeader(
                        title: "Settings",
                        subtitle: "Tune Luna's experience, appearance, and app details."
                    )

                    generalSection
                    appIconSection
                    experienceSection
                    dailyFactSection
                    profileSection
                    storageSection
                }
                .screenContentPadding()
            }
            .onAppear {
                scrollForGuidedTourStep(appState.guidedTourStep, proxy: proxy)
            }
            .onChange(of: appState.guidedTourStep) { step in
                scrollForGuidedTourStep(step, proxy: proxy)
            }
        }
        .appBackground()
    }

    private var experienceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Experience")

            CardSection {
                Button {
                    appState.restartTour()
                } label: {
                    CardRow {
                        RowLabel(
                            title: "Replay App Tour",
                            subtitle: "Show the guided walkthrough again without changing preferences",
                            systemImage: "sparkles",
                            showsChevron: true
                        )
                    }
                }
                .buttonStyle(.plain)
                .hapticTap()
                .accessibilityIdentifier("settings.replayTour")
                .guidedTourTarget(.settingsReplayTour, when: appState.guidedTourStep == .finish)
                .id(ScrollAnchor.replayTour)

                CardDivider(leadingInset: 56)
                
                NavigationLink {
                    SettingsViewingModeView(
                        prefersARMode: Binding(
                            get: { appState.experiencePreferences.prefersARMode },
                            set: { appState.setPrefersARMode($0) }
                        )
                    )
                    .appBackground()
                } label: {
                    CardRow {
                        RowLabel(
                            title: "View Mode",
                            subtitle: currentViewModeSubtitle,
                            systemImage: "arkit",
                            value: currentViewModeTitle,
                            showsChevron: true
                        )
                    }
                }
                .buttonStyle(.plain)
                .hapticTap()

                CardDivider(leadingInset: 56)

                NavigationLink {
                    SettingsScaleModeView(
                        distanceScaleMode: Binding(
                            get: { appState.experiencePreferences.distanceScaleMode },
                            set: { appState.setDistanceScaleMode($0) }
                        ),
                        objectScaleMode: Binding(
                            get: { appState.experiencePreferences.objectScaleMode },
                            set: { appState.setObjectScaleMode($0) }
                        ),
                        distanceCompression: Binding(
                            get: { appState.experiencePreferences.distanceCompression },
                            set: { appState.setDistanceCompression($0) }
                        )
                    )
                    .appBackground()
                } label: {
                    CardRow {
                        RowLabel(
                            title: "Scaling",
                            subtitle: currentScaleModeSubtitle,
                            systemImage: "scale.3d",
                            value: appState.experiencePreferences.distanceScaleMode.title,
                            showsChevron: true
                        )
                    }
                }
                .buttonStyle(.plain)
                .hapticTap()

                CardDivider(leadingInset: 56)

                CardRow {
                    Toggle(
                        isOn: Binding(
                            get: { appState.experiencePreferences.showLabels },
                            set: { setShowLabels($0) }
                        )
                    ) {
                        RowLabel(
                            title: "Labels",
                            subtitle: "Show names and values in visual scenes",
                            systemImage: "tag"
                        )
                    }
                }

                CardDivider(leadingInset: 56)

                CardRow {
                    Toggle(
                        isOn: Binding(
                            get: { appState.experiencePreferences.showOrbits },
                            set: { setShowOrbits($0) }
                        )
                    ) {
                        RowLabel(
                            title: "Orbits",
                            subtitle: "Show orbit guides in visual scenes",
                            systemImage: "circle.dashed"
                        )
                    }
                }
            }
        }
    }

    private var dailyFactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Daily Fact")

            CardSection {
                Button {
                    appState.refreshDailyFact()
                } label: {
                    CardRow {
                        RowLabel(
                            title: "Refresh Daily Fact",
                            subtitle: "Get a different fact and featured body",
                            systemImage: "arrow.clockwise",
                            showsChevron: true
                        )
                    }
                }
                .buttonStyle(.plain)
                .hapticTap()
            }
        }
    }

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Storage")

            CardSection {
                Button {
                    Haptics.selection()
                    isShowingAPODCacheClearConfirmation = true
                } label: {
                    CardRow {
                        RowLabel(
                            title: "Clear NASA Image Cache",
                            subtitle: apodCacheStatusMessage ?? "Remove saved APOD metadata and image files",
                            systemImage: "trash",
                            showsChevron: true
                        )
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
        .confirmationDialog(
            "Clear NASA image cache?",
            isPresented: $isShowingAPODCacheClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Cache", role: .destructive) {
                clearAPODCache()
            }

            Button("Cancel", role: .cancel) {
                Haptics.selection()
            }
        } message: {
            Text("This removes saved NASA image metadata and cached APOD image files. Luna will fetch the latest image again next time it loads.")
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Profile")

            CardSection {
                CardRow {
                    RowLabel(
                        title: "Display Name",
                        subtitle: "Optional profile setup arrives with onboarding",
                        systemImage: "textformat",
                        value: appState.userProfile.displayName ?? "Not set"
                    )
                }

                CardDivider(leadingInset: 56)

                Button {
                    Haptics.selection()
                    isShowingResetConfirmation = true
                } label: {
                    CardRow {
                        RowLabel(
                            title: "Reset User",
                            subtitle: "Clear profile choices and show onboarding again",
                            systemImage: "arrow.counterclockwise",
                            showsChevron: true
                        )
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
        .confirmationDialog(
            "Reset Luna?",
            isPresented: $isShowingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset User", role: .destructive) {
                Haptics.selection()
                appState.resetUserProfile()
            }

            Button("Cancel", role: .cancel) {
                Haptics.selection()
            }
        } message: {
            Text("This clears your display name and Luna preferences, then shows onboarding again.")
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "General")

            CardSection {
                CardRow {
                    HStack(spacing: 12) {
                        RowLabel(
                            title: "Appearance",
                            subtitle: "Use system, light, or dark mode",
                            systemImage: "circle.lefthalf.filled"
                        )

                        Spacer(minLength: 12)

                        Picker(
                            "Appearance",
                            selection: Binding(
                                get: { appState.appearancePreference },
                                set: { setAppearancePreference($0) }
                            )
                        ) {
                            ForEach(AppAppearancePreference.allCases) { preference in
                                Text(preference.title).tag(preference)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }

                CardDivider(leadingInset: 56)

                if Haptics.isSupported {
                    CardRow {
                        Toggle(
                            isOn: Binding(
                                get: { appState.userProfile.hapticsEnabled },
                                set: { setHapticsEnabled($0) }
                            )
                        ) {
                            RowLabel(
                                title: "Haptics",
                                subtitle: "Use press feedback across Luna",
                                systemImage: "hand.tap"
                            )
                        }
                    }

                    CardDivider(leadingInset: 56)

                    CardRow {
                        HStack(spacing: 12) {
                            RowLabel(
                                title: "Haptic Strength",
                                subtitle: "Choose how firm button presses feel",
                                systemImage: "waveform.path.ecg"
                            )

                            Spacer(minLength: 12)

                            Picker(
                                "Haptic Strength",
                                selection: Binding(
                                    get: { appState.userProfile.hapticIntensity },
                                    set: { setHapticIntensity($0) }
                                )
                            ) {
                                ForEach(HapticIntensity.allCases) { intensity in
                                    Text(intensity.title).tag(intensity)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .disabled(!appState.userProfile.hapticsEnabled)
                        }
                        .opacity(appState.userProfile.hapticsEnabled ? 1 : 0.55)
                    }

                    CardDivider(leadingInset: 56)
                }

                NavigationLink {
                    AboutView()
                        .appBackground()
                } label: {
                    CardRow {
                        RowLabel(
                            title: "About",
                            subtitle: "Version, build, and project details",
                            systemImage: "info.circle",
                            showsChevron: true
                        )
                    }
                }
                .buttonStyle(.plain)
                .hapticTap()
            }
        }
    }

    private var appIconSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "App Icon")

            CardSection {
                NavigationLink {
                    AppIconSettingsView(
                        selectedChoice: appState.selectedAppIconChoice,
                        onSelect: appState.setAppIconChoice
                    )
                    .appBackground()
                } label: {
                    CardRow {
                        RowLabel(
                            title: "App Icon",
                            subtitle: "Choose Luna's Home Screen icon",
                            systemImage: "app.badge",
                            value: appState.selectedAppIconChoice.title,
                            showsChevron: true
                        )
                    }
                }
                .buttonStyle(.plain)
                .hapticTap()
            }
        }
    }

    private func setAppearancePreference(_ preference: AppAppearancePreference) {
        Haptics.selection()
        appState.setAppearancePreference(preference)
    }

    private func setShowLabels(_ showLabels: Bool) {
        Haptics.selection()
        appState.setShowLabels(showLabels)
    }

    private func setShowOrbits(_ showOrbits: Bool) {
        Haptics.selection()
        appState.setShowOrbits(showOrbits)
    }

    private func setHapticsEnabled(_ isEnabled: Bool) {
        if isEnabled {
            appState.setHapticsEnabled(isEnabled)
            Haptics.selection()
        } else {
            Haptics.selection()
            appState.setHapticsEnabled(isEnabled)
        }
    }

    private func setHapticIntensity(_ intensity: HapticIntensity) {
        appState.setHapticIntensity(intensity)
        Haptics.selection()
    }

    private func clearAPODCache() {
        do {
            try imageOfTheDayRepository.clearCache()
            apodCacheStatusMessage = "NASA image cache cleared"
            Haptics.selection()
        } catch {
            apodCacheStatusMessage = "Could not clear NASA image cache"
            Haptics.selection()
        }
    }

    private func scrollForGuidedTourStep(_ step: GuidedTourStep?, proxy: ScrollViewProxy) {
        guard step == .finish else { return }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(ScrollAnchor.replayTour, anchor: .center)
            }
        }
    }

    private var currentViewModeTitle: String {
        appState.experiencePreferences.prefersARMode ? "AR First" : "Visual First"
    }

    private var currentViewModeSubtitle: String {
        appState.experiencePreferences.prefersARMode
            ? "Starts space views with AR when available"
            : "Starts with the non-AR visual mode"
    }

    private var currentScaleModeSubtitle: String {
        switch appState.experiencePreferences.distanceScaleMode {
        case .educational:
            return "Equal readable distances, \(appState.experiencePreferences.objectScaleMode.title.lowercased()) object scale"
        case .compressed:
            return "Compressed to \(Int(appState.experiencePreferences.distanceCompression.rounded()))x, \(appState.experiencePreferences.objectScaleMode.title.lowercased()) objects"
        case .trueScale:
            return "Accurate intent, impractical at room scale"
        }
    }
}

private struct SettingsViewingModeView: View {
    @Binding var prefersARMode: Bool

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.section) {
                PageHeader(
                    title: "Choose View Mode",
                    subtitle: "Pick the experience Luna should prefer when opening space views."
                )

                ViewingModeOptionsView(prefersARMode: $prefersARMode)
            }
            .screenContentPadding()
        }
        .navigationTitle("View Mode")
    }
}

private struct SettingsScaleModeView: View {
    @Binding var distanceScaleMode: DistanceScaleMode
    @Binding var objectScaleMode: ObjectScaleMode
    @Binding var distanceCompression: Double

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.section) {
                PageHeader(
                    title: "Choose Scaling",
                    subtitle: "Pick how Luna should balance accurate scale with readable space views."
                )

                DistanceScaleOptionsView(
                    distanceScaleMode: $distanceScaleMode,
                    distanceCompression: $distanceCompression
                )

                ObjectScaleOptionsView(objectScaleMode: $objectScaleMode)
            }
            .screenContentPadding()
        }
        .navigationTitle("Scaling")
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                appIdentityCard

                appSection

                creditsSection

                websiteSection

                projectSection
            }
            .screenContentPadding()
        }
        .appBackground()
        .navigationTitle("About")
    }

    private var appIdentityCard: some View {
        Card {
            HStack(spacing: 12) {
                IconBadge(systemImage: "moon.stars.fill")

                VStack(alignment: .leading, spacing: 2) {
                    Text("Luna")
                        .font(.headline)

                    Text("Explore planets, scale, and space in AR.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "App")

            CardSection {
                CardRow {
                    aboutRow(title: "Version", value: appVersion)
                }

                CardDivider()

                CardRow {
                    aboutRow(title: "Build", value: appBuild)
                }
            }
        }
    }

    private var websiteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Website")

            CardSection {
                Link(destination: URL(string: "https://novapro.net")!) {
                    CardRow {
                        HStack(spacing: 12) {
                            IconBadge(systemImage: "globe")

                            Text("novapro.net")
                                .font(.headline)

                            Spacer(minLength: 8)

                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .hapticTap()
            }
        }
    }

    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Credits")

            CardSection {
                NavigationLink {
                    CreditsView()
                        .appBackground()
                } label: {
                    CardRow {
                        RowLabel(
                            title: "NASA Asset Credits",
                            subtitle: "Sources, usage notes, and direct links",
                            systemImage: "sparkles",
                            showsChevron: true
                        )
                    }
                }
                .buttonStyle(.plain)
                .hapticTap()
            }
        }
    }

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Project")

            Card {
                Text("Luna is an AR space app developed by Daniel Kravec at Nova Productions. This b14 rewrite is rebuilding the app for iOS, iPadOS, and macOS with AR as a main experience and a non-AR visual mode for every platform.")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }

        return "Unknown"
    }

    private var appBuild: String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return build
        }

        return "Unknown"
    }

    private func aboutRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }
}

private struct CreditsView: View {
    private let catalog: AssetCreditCatalog

    init(catalog: AssetCreditCatalog = AssetCreditLoader().load()) {
        self.catalog = catalog
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.section) {
                PageHeader(
                    title: "Credits",
                    subtitle: "Asset sources, usage notes, and direct links for Luna's NASA-backed visuals."
                )

                if catalog.groups.isEmpty {
                    EmptyStateView(
                        title: "Credits Unavailable",
                        systemImage: "exclamationmark.triangle",
                        message: "Luna could not load the bundled asset credit catalog."
                    )
                } else {
                    ForEach(catalog.groups) { group in
                        creditGroupSection(group)
                    }
                }
            }
            .screenContentPadding()
        }
        .navigationTitle("Credits")
    }

    private func creditGroupSection(_ group: AssetCreditGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: group.title, subtitle: group.summary)

            CardSection {
                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                    CardRow {
                        creditItemView(item)
                    }

                    if index < group.items.count - 1 {
                        CardDivider(leadingInset: 56)
                    }
                }
            }
        }
    }

    private func creditItemView(_ item: AssetCreditItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RowLabel(
                title: item.name,
                subtitle: item.path,
                systemImage: "photo"
            )

            Text(item.credit)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.licenseNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(item.links) { link in
                    Link(destination: link.url) {
                        Label(link.title, systemImage: "arrow.up.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .hapticTap()
                }
            }
        }
    }
}

private struct AssetCreditCatalog: Codable, Equatable {
    let groups: [AssetCreditGroup]

    static let empty = AssetCreditCatalog(groups: [])
}

private struct AssetCreditGroup: Codable, Equatable, Identifiable {
    var id: String { title }

    let title: String
    let summary: String
    let items: [AssetCreditItem]
}

private struct AssetCreditItem: Codable, Equatable, Identifiable {
    var id: String { path }

    let name: String
    let path: String
    let credit: String
    let licenseNote: String
    let sourceURL: String
    let usageURL: String

    var links: [AssetCreditLink] {
        var links: [AssetCreditLink] = []

        if let source = URL(string: sourceURL) {
            links.append(AssetCreditLink(title: "Source", url: source))
        }

        if let usage = URL(string: usageURL) {
            links.append(AssetCreditLink(title: "Usage Guidelines", url: usage))
        }

        return links
    }
}

private struct AssetCreditLink: Equatable, Identifiable {
    var id: String { url.absoluteString }

    let title: String
    let url: URL
}

private struct AssetCreditLoader {
    var bundle: Bundle = .main
    var resourceName = "asset_sources"
    var decoder = JSONDecoder()

    func load() -> AssetCreditCatalog {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            return .empty
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(AssetCreditCatalog.self, from: data)
        } catch {
            return .empty
        }
    }
}
