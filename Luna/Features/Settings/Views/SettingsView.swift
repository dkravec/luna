import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: LunaAppState
    @State private var isShowingResetConfirmation = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                PageHeader(
                    title: "Settings",
                    subtitle: "Tune Luna's experience, appearance, and app details."
                )

                generalSection
                experienceSection
                profileSection
            }
            .screenContentPadding()
        }
        .appBackground()
    }

    private var experienceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Experience")

            CardSection {
                NavigationLink {
                    SettingsViewingModeView(
                        prefersARMode: Binding(
                            get: { appState.userProfile.prefersARMode },
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
                        preferredScaleMode: Binding(
                            get: { appState.userProfile.preferredScaleMode },
                            set: { appState.setPreferredScaleMode($0) }
                        ),
                        distanceCompression: Binding(
                            get: { appState.userProfile.distanceCompression },
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
                            value: appState.userProfile.preferredScaleMode.title,
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
                            get: { appState.userProfile.showLabels },
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
                            get: { appState.userProfile.showOrbits },
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

    private var currentViewModeTitle: String {
        appState.userProfile.prefersARMode ? "AR First" : "Visual First"
    }

    private var currentViewModeSubtitle: String {
        appState.userProfile.prefersARMode
            ? "Starts space views with AR when available"
            : "Starts with the non-AR visual mode"
    }

    private var currentScaleModeSubtitle: String {
        switch appState.userProfile.preferredScaleMode {
        case .educational:
            return "Readable sizes and distances together"
        case .compressedDistance:
            return "Compressed to \(Int(appState.userProfile.distanceCompression.rounded()))x for comparison"
        case .trueDistance:
            return "Accurate intent, impractical at room scale"
        case .custom:
            return "Uses your custom scale controls"
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
    @Binding var preferredScaleMode: ScaleMode
    @Binding var distanceCompression: Double

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.section) {
                PageHeader(
                    title: "Choose Scaling",
                    subtitle: "Pick how Luna should balance accurate scale with readable space views."
                )

                ScaleModeOptionsView(
                    preferredScaleMode: $preferredScaleMode,
                    distanceCompression: $distanceCompression
                )
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
