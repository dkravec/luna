import SwiftUI

enum GuidedTourTarget: Hashable {
    case homeOverview
    case homeExploreAction
    case homeExperienceAction
    case exploreCategory
    case exploreBody
    case bodyDetailExperience
    case experienceScene
    case experienceModeToggle
    case experienceControls
    case experiencePlayback
}

private struct GuidedTourTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [GuidedTourTarget: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [GuidedTourTarget: Anchor<CGRect>],
        nextValue: () -> [GuidedTourTarget: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

extension View {
    func guidedTourTarget(_ target: GuidedTourTarget) -> some View {
        anchorPreference(key: GuidedTourTargetPreferenceKey.self, value: .bounds) { anchor in
            [target: anchor]
        }
    }

    @ViewBuilder
    func guidedTourTarget(_ target: GuidedTourTarget, when condition: Bool) -> some View {
        if condition {
            guidedTourTarget(target)
        } else {
            self
        }
    }

    func guidedTourOverlay(appState: LunaAppState) -> some View {
        coordinateSpace(name: "GuidedTourSpace")
            .overlayPreferenceValue(GuidedTourTargetPreferenceKey.self) { preferences in
                GeometryReader { proxy in
                    if let step = appState.guidedTourStep {
                        let targetFrame = preferences[step.target].map { proxy[$0] }
                        GuidedTourOverlayView(
                            step: step,
                            targetFrame: targetFrame,
                            safeAreaInsets: proxy.safeAreaInsets,
                            canUseAR: appState.canUseARForGuidedTour,
                            canGoBack: appState.canGoBackTour,
                            onNext: appState.advanceTour,
                            onBack: appState.goBackTour,
                            onSkip: appState.skipTour
                        )
                        .id(appState.guidedTourPresentationID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                    }
                }
            }
    }
}

private struct GuidedTourOverlayView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var calloutSize: CGSize = CGSize(width: 320, height: 190)

    let step: GuidedTourStep
    let targetFrame: CGRect?
    let safeAreaInsets: EdgeInsets
    let canUseAR: Bool
    let canGoBack: Bool
    let onNext: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let highlightedFrame = highlightFrame(in: proxy.size)
            let cardWidth = min(proxy.size.width - 32, horizontalSizeClass == .regular ? 420 : 360)

            ZStack {
                GuidedTourDimShape(highlightFrame: highlightedFrame)
                    .fill(Color.black.opacity(0.58), style: FillStyle(eoFill: true))
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.95), lineWidth: 2)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    }
                    .shadow(color: Color.black.opacity(0.32), radius: 18, x: 0, y: 8)
                    .frame(width: highlightedFrame.width, height: highlightedFrame.height)
                    .position(x: highlightedFrame.midX, y: highlightedFrame.midY)
                    .allowsHitTesting(false)

                calloutCard
                    .frame(width: cardWidth)
                    .readGuidedTourCalloutSize()
                    .contentShape(RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
                    .allowsHitTesting(true)
                    .position(calloutPosition(cardSize: measuredCalloutSize(width: cardWidth), proxySize: proxy.size, targetFrame: highlightedFrame))
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: step)
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: targetFrame)
            .onPreferenceChange(GuidedTourCalloutSizePreferenceKey.self) { size in
                guard size != .zero else { return }
                calloutSize = size
            }
        }
        .zIndex(200)
        .transition(.opacity)
    }

    private var calloutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(step.progressText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                if canGoBack {
                    Button("Back") {
                        onBack()
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                }

                Button("End Tour") {
                    onSkip()
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            }

            Text(step.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Text(step.message(canUseAR: canUseAR))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onNext) {
                Text(step.primaryButtonTitle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(Color.accentColor, in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.24), radius: 24, x: 0, y: 12)
    }

    private func highlightFrame(in size: CGSize) -> CGRect {
        if let targetFrame, !targetFrame.isEmpty {
            let paddedFrame = targetFrame.insetBy(dx: -6, dy: -6)
            let visibleBounds = CGRect(origin: .zero, size: size)
            let clippedFrame = paddedFrame.intersection(visibleBounds)
            if !clippedFrame.isNull, clippedFrame.width > 1, clippedFrame.height > 1 {
                return clippedFrame
            }
        }

        return CGRect(
            x: 24,
            y: max(size.height * 0.18, safeAreaInsets.top + 72),
            width: max(80, size.width - 48),
            height: min(280, size.height * 0.34)
        )
    }

    private func measuredCalloutSize(width: CGFloat) -> CGSize {
        CGSize(width: width, height: max(140, calloutSize.height))
    }

    private func calloutPosition(cardSize: CGSize, proxySize: CGSize, targetFrame: CGRect) -> CGPoint {
        let verticalGap: CGFloat = 18
        let safeHorizontal = cardSize.width / 2 + 16
        let safeTop = safeAreaInsets.top + 16
        let safeBottom = proxySize.height - safeAreaInsets.bottom - 16
        let verticalBias: CGFloat = 10
        let x = min(max(targetFrame.midX, safeHorizontal), proxySize.width - safeHorizontal)

        if targetFrame.height >= proxySize.height * 0.55 {
            let centeredY = proxySize.height * 0.68
            return CGPoint(
                x: proxySize.width / 2,
                y: min(max(centeredY + verticalBias, safeTop + cardSize.height / 2 + 12), safeBottom - cardSize.height / 2)
            )
        }

        let proposedBelow = targetFrame.maxY + verticalGap + cardSize.height / 2
        let proposedAbove = targetFrame.minY - verticalGap - cardSize.height / 2

        if proposedBelow + cardSize.height / 2 <= safeBottom {
            return CGPoint(x: x, y: min(proposedBelow + verticalBias, safeBottom - cardSize.height / 2))
        }

        if proposedAbove - cardSize.height / 2 >= safeTop {
            return CGPoint(x: x, y: min(max(proposedAbove + verticalBias, safeTop + cardSize.height / 2), safeBottom - cardSize.height / 2))
        }

        return CGPoint(
            x: proxySize.width / 2,
            y: min(max(safeBottom - cardSize.height / 2 - 8, safeTop + cardSize.height / 2), safeBottom - cardSize.height / 2)
        )
    }
}

private struct GuidedTourCalloutSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

private extension View {
    func readGuidedTourCalloutSize() -> some View {
        background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: GuidedTourCalloutSizePreferenceKey.self, value: proxy.size)
            }
        }
    }
}

private struct GuidedTourDimShape: Shape {
    let highlightFrame: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(
            in: highlightFrame,
            cornerSize: CGSize(width: 18, height: 18)
        )
        return path
    }
}
