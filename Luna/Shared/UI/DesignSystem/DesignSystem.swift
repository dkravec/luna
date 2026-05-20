import SwiftUI
#if os(iOS)
import UIKit
#endif

enum Palette {
#if os(macOS)
    static let background = Color(nsColor: .windowBackgroundColor)
#else
    static let background = Color(.systemBackground)
#endif
    static let spaceBlack = Color(red: 0.02, green: 0.02, blue: 0.04)
    static let softWhite = Color.white.opacity(0.86)
    static let moonGrey = Color(red: 0.76, green: 0.76, blue: 0.80)
    static let orbitBlue = Color(red: 0.36, green: 0.52, blue: 0.96)
}

struct AppBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .top) {
            backgroundBase

            LinearGradient(
                colors: gradientStops,
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: colorScheme == .dark ? 460 : 420)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
    }

    private var backgroundBase: Color {
        colorScheme == .dark ? Palette.spaceBlack : Palette.background
    }

    private var gradientStops: [Color] {
        if colorScheme == .dark {
            return [
                Palette.softWhite.opacity(0.62),
                Palette.moonGrey.opacity(0.24),
                Color.clear
            ]
        }

        return [
            Palette.moonGrey.opacity(0.46),
            Palette.moonGrey.opacity(0.16),
            Color.clear
        ]
    }
}

enum Spacing {
    static let screenHorizontal: CGFloat = 16
    static let screenVertical: CGFloat = 12
    static let screenBottom: CGFloat = 32
    static let customTabBarBottomReserve: CGFloat = 80
    static let section: CGFloat = 12
    static let card: CGFloat = 14
}

enum Radii {
    static let card: CGFloat = 16
    static let tile: CGFloat = 10
    static let rowIcon: CGFloat = 8
}

struct Card<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let isSelected: Bool
    let content: Content

    init(isSelected: Bool = false, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardFill, in: RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : cardBorder, lineWidth: isSelected ? 1.5 : 1)
            }
            .shadow(
                color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.10),
                radius: 10,
                x: 0,
                y: 4
            )
            .contentShape(RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
    }

    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.10)
    }

    private var cardFill: some ShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(isSelected ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.08))
        }

        if isSelected {
            return AnyShapeStyle(Color.accentColor.opacity(0.14))
        }

        return AnyShapeStyle(.regularMaterial)
    }
}

struct ActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    enum Emphasis {
        case primary
        case secondary
    }

    let emphasis: Emphasis

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .frame(minHeight: 42)
            .frame(maxWidth: .infinity)
            .background(background(configuration: configuration), in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(border, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch emphasis {
        case .primary:
            return colorScheme == .dark ? Palette.spaceBlack : Color.white
        case .secondary:
            return .primary
        }
    }

    private func background(configuration: Configuration) -> some ShapeStyle {
        let opacity = configuration.isPressed ? 0.78 : 1

        switch emphasis {
        case .primary:
            return AnyShapeStyle(Color.primary.opacity(opacity))
        case .secondary:
            if colorScheme == .dark {
                return AnyShapeStyle(Color.white.opacity(0.08))
            }

            return AnyShapeStyle(.regularMaterial)
        }
    }

    private var border: Color {
        emphasis == .primary ? Color.clear : Color.primary.opacity(0.12)
    }
}

struct CardSection<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground())
        .contentShape(RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
    }
}

struct CardRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.card)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CardDivider: View {
    var leadingInset: CGFloat = 14

    var body: some View {
        Divider()
            .padding(.leading, leadingInset)
    }
}

struct CardBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = Radii.card

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(cardFill)
            .overlay {
                if colorScheme == .light {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.30))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(cardBorder, lineWidth: 1)
            }
            .shadow(
                color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.10),
                radius: 10,
                x: 0,
                y: 4
            )
    }

    private var cardFill: some ShapeStyle {
        colorScheme == .dark ? AnyShapeStyle(Color.white.opacity(0.08)) : AnyShapeStyle(.regularMaterial)
    }

    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.10)
    }
}

struct DetailMediaCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .background(CardBackground())
            .clipShape(RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
            .accessibilityElement(children: .contain)
    }
}

struct DetailMetadataCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                content
            }
        }
    }
}

struct DetailTextCard: View {
    let title: String?
    let text: String

    init(title: String? = nil, text: String) {
        self.title = title
        self.text = text
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                if let title {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .accessibilityAddTraits(.isHeader)
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.headline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RowLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var value: String?
    var showsChevron = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct IconBadge: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            IconBadge(systemImage: systemImage)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(cornerRadius: Radii.tile))
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        Card {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    func hapticTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                Haptics.selection()
            }
        )
    }

    func appBackground() -> some View {
        background(AppBackgroundView())
    }

    func screenContentPadding() -> some View {
        modifier(ScreenContentPaddingModifier())
    }

    func lunaCustomTabBarBottomReserve(_ isActive: Bool = true) -> some View {
        environment(\.lunaCustomTabBarReserveIsActive, isActive)
    }

    func primaryActionButton() -> some View {
        buttonStyle(ActionButtonStyle(emphasis: .primary))
            .hapticTap()
    }

    func secondaryActionButton() -> some View {
        buttonStyle(ActionButtonStyle(emphasis: .secondary))
            .hapticTap()
    }
}

private struct ScreenContentPaddingModifier: ViewModifier {
    @Environment(\.lunaCustomTabBarReserveIsActive) private var customTabBarReserveIsActive

    func body(content: Content) -> some View {
        let bottomReserve = customTabBarReserveIsActive ? Spacing.customTabBarBottomReserve : 0

        content
            .frame(maxWidth: 600, alignment: .leading)
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.screenVertical)
            .padding(.bottom, Spacing.screenBottom + bottomReserve)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct LunaCustomTabBarReserveActiveKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var lunaCustomTabBarReserveIsActive: Bool {
        get { self[LunaCustomTabBarReserveActiveKey.self] }
        set { self[LunaCustomTabBarReserveActiveKey.self] = newValue }
    }
}

enum Haptics {
    private static var isEnabled = UserProfile.defaultProfile.hapticsEnabled
    private static var intensity = UserProfile.defaultProfile.hapticIntensity

    static var isSupported: Bool {
#if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
#else
        false
#endif
    }

    static func configure(isEnabled: Bool, intensity: HapticIntensity) {
        Self.isEnabled = isEnabled
        Self.intensity = intensity
    }

    static func selection() {
#if os(iOS)
        guard isEnabled, isSupported else { return }

        let generator = UIImpactFeedbackGenerator(style: intensity.impactStyle)
        generator.prepare()
        generator.impactOccurred()
#endif
    }
}

#if os(iOS)
private extension HapticIntensity {
    var impactStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light:
            return .light
        case .medium:
            return .medium
        case .heavy:
            return .heavy
        }
    }
}
#endif

struct BodyCardVisual: View {
    let celestialBody: CelestialBody
    let size: CGFloat

    var body: some View {
        if let image = Self.image(for: celestialBody) {
            Self.swiftUIImage(image)
                .resizable()
                .scaledToFit()
                .padding(8)
                .frame(width: size, height: size)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Radii.tile, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }
        } else {
            BodyVisual(celestialBody: celestialBody, size: size)
        }
    }

    private static func image(for body: CelestialBody) -> BundledThumbnailImage? {
        BundledThumbnailImageLoader.image(named: body.thumbnailName)
    }

    private static func swiftUIImage(_ image: BundledThumbnailImage) -> Image {
#if os(iOS)
        Image(uiImage: image)
#elseif os(macOS)
        Image(nsImage: image)
#endif
    }
}
