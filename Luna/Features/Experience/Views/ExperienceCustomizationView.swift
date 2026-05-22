import SwiftUI

struct ExperienceCustomizationView: View {
    let canUseAR: Bool
    var liveMode: Binding<Bool>? = nil
    var preferredARMode: Binding<Bool>? = nil
    @Binding var sceneScaleProfile: SceneScaleProfile
    @Binding var distanceScaleMode: DistanceScaleMode
    @Binding var objectScaleMode: ObjectScaleMode
    @Binding var distanceCompression: Double
    @Binding var renderDetail: SceneRenderDetail
    @Binding var showLabels: Bool
    @Binding var showOrbits: Bool
    var setSceneMode: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            viewModeSection
            SceneScaleProfileOptionsView(sceneScaleProfile: $sceneScaleProfile)
            if sceneScaleProfile == .custom {
                DistanceScaleOptionsView(
                    distanceScaleMode: $distanceScaleMode,
                    distanceCompression: $distanceCompression
                )
                ObjectScaleOptionsView(objectScaleMode: $objectScaleMode)
            }
            sceneOptionsSection
        }
    }

    private var usesARMode: Bool {
        liveMode?.wrappedValue ?? preferredARMode?.wrappedValue ?? false
    }

    private var viewModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: liveMode == nil ? "Default Viewing Mode" : "View Mode")

            CardSection {
                SelectionRow(
                    title: liveMode == nil ? "AR First" : "AR",
                    subtitle: canUseAR ? "Place scaled bodies in your space." : "AR is not available on this device.",
                    systemImage: "arkit",
                    value: canUseAR ? nil : "Unavailable",
                    isSelected: usesARMode
                ) {
                    setARMode(true)
                }
                .disabled(!canUseAR && liveMode != nil)

                CardDivider(leadingInset: 56)

                SelectionRow(
                    title: liveMode == nil ? "Visual First" : "Visual",
                    subtitle: "Use the same scene controls without AR.",
                    systemImage: "cube.transparent",
                    isSelected: !usesARMode
                ) {
                    setARMode(false)
                }
            }
        }
    }

    private var sceneOptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Scene")

            CardSection {
                CardRow {
                    Toggle(isOn: $showLabels) {
                        RowLabel(
                            title: "Labels",
                            subtitle: "Show body names in visual scenes.",
                            systemImage: "tag"
                        )
                    }
                }

                CardDivider(leadingInset: 56)

                CardRow {
                    Toggle(isOn: $showOrbits) {
                        RowLabel(
                            title: "Orbit Guides",
                            subtitle: "Show subtle distance guides in visual mode.",
                            systemImage: "circle.dashed"
                        )
                    }
                }

                CardDivider(leadingInset: 56)

                CardRow {
                    Picker("Render Detail", selection: $renderDetail) {
                        ForEach(SceneRenderDetail.allCases) { detail in
                            Text(detail.title).tag(detail)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private func setARMode(_ isAR: Bool) {
        if liveMode != nil {
            setSceneMode(isAR)
        } else {
            preferredARMode?.wrappedValue = isAR
        }
    }
}
