import SwiftUI

private enum GuidedTourCoordinateSpace {
    static let name = "GuidedTourCoordinateSpace"
}

private struct GuidedTourTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [GuidedTourTarget: CGRect] = [:]

    static func reduce(
        value: inout [GuidedTourTarget: CGRect],
        nextValue: () -> [GuidedTourTarget: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

extension View {
    func guidedTourTarget(_ target: GuidedTourTarget) -> some View {
        accessibilityElement(children: .combine)
            .accessibilityIdentifier(target.accessibilityIdentifier)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: GuidedTourTargetPreferenceKey.self,
                            value: [target: proxy.frame(in: .named(GuidedTourCoordinateSpace.name))]
                        )
                }
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
        coordinateSpace(name: GuidedTourCoordinateSpace.name)
            .overlayPreferenceValue(GuidedTourTargetPreferenceKey.self) { targetFrames in
                GeometryReader { proxy in
                    if let step = appState.guidedTourStep {
                        GuidedTourOverlayView(
                            step: step,
                            targetFrame: targetFrames[step.target],
                            containerSize: proxy.size,
                            safeAreaInsets: proxy.safeAreaInsets,
                            canUseAR: appState.canUseARForGuidedTour,
                            canGoBack: appState.canGoBackTour,
                            onNext: appState.advanceTour,
                            onBack: appState.goBackTour,
                            onSkip: appState.skipTour,
                            onTargetTap: {
                                _ = appState.guidedTourTargetTapped(step.target)
                            }
                        )
                        .id("\(appState.guidedTourPresentationID.uuidString)-\(step.id)")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(true)
                    }
                }
            }
            .overlay {
                if let step = appState.guidedTourStep {
                    GuidedTourFloatingCalloutView(
                        step: step,
                        canUseAR: appState.canUseARForGuidedTour,
                        canGoBack: appState.canGoBackTour,
                        onNext: appState.advanceTour,
                        onBack: appState.goBackTour,
                        onSkip: appState.skipTour
                    )
                    .id("callout-\(appState.guidedTourPresentationID.uuidString)-\(step.id)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(true)
                    .zIndex(250)
                }
            }
            .id(appState.guidedTourDismissalID ?? appState.guidedTourPresentationID)
    }
}

private struct GuidedTourOverlayView: View {
    @State private var allowsMissingTargetFallback = false

    let step: GuidedTourStep
    let targetFrame: CGRect?
    let containerSize: CGSize
    let safeAreaInsets: EdgeInsets
    let canUseAR: Bool
    let canGoBack: Bool
    let onNext: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void
    let onTargetTap: () -> Void

    var body: some View {
        let highlightedFrame = highlightFrame(in: containerSize)

        ZStack {
            safeAreaDimStrips

            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityLabel("Tour overlay")
                .accessibilityIdentifier("tour.overlay")
                .allowsHitTesting(false)

            if let highlightedFrame {
                GuidedTourDimShape(highlightFrame: highlightedFrame)
                    .fill(Color.black.opacity(0.58), style: FillStyle(eoFill: true))
                    .accessibilityHidden(true)
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
                    .accessibilityIdentifier("tour.spotlight")
                    .accessibilityLabel("Tour spotlight")
                    .allowsHitTesting(false)

                Color.white.opacity(0.001)
                    .frame(width: highlightedFrame.width, height: highlightedFrame.height)
                    .position(x: highlightedFrame.midX, y: highlightedFrame.midY)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTargetTap)
                    .zIndex(1)
            } else {
                Color.black.opacity(0.58)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }

        }
        .frame(width: containerSize.width, height: containerSize.height)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: step)
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: targetFrame)
        .allowsHitTesting(true)
        .zIndex(200)
        .transition(.opacity)
        .onAppear {
            scheduleMissingTargetFallback()
        }
        .onChange(of: step) { _ in
            allowsMissingTargetFallback = false
            scheduleMissingTargetFallback()
        }
    }

    static func calloutCard(
        step: GuidedTourStep,
        canUseAR: Bool,
        canGoBack: Bool,
        onNext: @escaping () -> Void,
        onBack: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(step.progressText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                if canGoBack {
                    Text("Back")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 56, minHeight: 44)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onBack)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("tour.back")
                }

                Text("End Tour")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 82, minHeight: 44)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onSkip)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("tour.end")
            }

            Text(step.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .accessibilityIdentifier("tour.title")

            Text(step.message(canUseAR: canUseAR))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("tour.message")

            Text(step.primaryButtonTitle)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(Color.accentColor, in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onNext)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("tour.next")
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.24), radius: 24, x: 0, y: 12)
    }

    private func highlightFrame(in size: CGSize) -> CGRect? {
        if let targetFrame, !targetFrame.isEmpty {
            let alignedFrame = targetFrame.offsetBy(dx: 0, dy: -safeAreaInsets.top)
            let paddedFrame = alignedFrame.insetBy(dx: -6, dy: -6)
            let visibleBounds = CGRect(origin: .zero, size: size)
            let clippedFrame = paddedFrame.intersection(visibleBounds)
            if !clippedFrame.isNull, clippedFrame.width > 1, clippedFrame.height > 1 {
                return clippedFrame
            }
        }

        guard allowsMissingTargetFallback else {
            return nil
        }

        return CGRect(
            x: 24,
            y: max(size.height * 0.18, safeAreaInsets.top + 72),
            width: max(80, size.width - 48),
            height: min(280, size.height * 0.34)
        )
    }

    private func scheduleMissingTargetFallback() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            allowsMissingTargetFallback = true
        }
    }

    private var safeAreaDimStrips: some View {
        ZStack {
            if safeAreaInsets.top > 0 {
                Color.black.opacity(0.58)
                    .frame(width: containerSize.width, height: safeAreaInsets.top)
                    .position(x: containerSize.width / 2, y: -safeAreaInsets.top / 2)
            }

            if safeAreaInsets.bottom > 0 {
                Color.black.opacity(0.58)
                    .frame(width: containerSize.width, height: safeAreaInsets.bottom)
                    .position(x: containerSize.width / 2, y: containerSize.height + safeAreaInsets.bottom / 2)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private struct GuidedTourFloatingCalloutView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let step: GuidedTourStep
    let canUseAR: Bool
    let canGoBack: Bool
    let onNext: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = min(proxy.size.width - 32, horizontalSizeClass == .regular ? 420 : 360)
            let usesTopPlacement = step == .homeExplore

            VStack {
                if !usesTopPlacement {
                    Spacer(minLength: 0)
                }

                GuidedTourOverlayView.calloutCard(
                    step: step,
                    canUseAR: canUseAR,
                    canGoBack: canGoBack,
                    onNext: onNext,
                    onBack: onBack,
                    onSkip: onSkip
                )
                .frame(width: cardWidth)
                .padding(.top, usesTopPlacement ? proxy.safeAreaInsets.top + 18 : 0)
                .padding(.bottom, usesTopPlacement ? 0 : proxy.safeAreaInsets.bottom + 24)

                if usesTopPlacement {
                    Spacer(minLength: 0)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
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
