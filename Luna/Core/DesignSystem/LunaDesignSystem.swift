import SwiftUI

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
#if os(macOS)
        colorScheme == .dark ? Color.black : Color(nsColor: .windowBackgroundColor)
#else
        colorScheme == .dark ? Color.black : Color(.systemBackground)
#endif
    }

    private var gradientStops: [Color] {
        if colorScheme == .dark {
            return [
                Color.white.opacity(0.72),
                Color.gray.opacity(0.30),
                Color.clear
            ]
        }

        return [
            Color.black.opacity(0.82),
            Color.gray.opacity(0.24),
            Color.clear
        ]
    }
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
            .padding(14)
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

    var body: some View {
        RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
            .fill(cardFill)
            .overlay {
                if colorScheme == .light {
                    RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
                        .fill(Color.white.opacity(0.30))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
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

extension View {
    func appBackground() -> some View {
        background(AppBackgroundView())
    }

    func screenContentPadding() -> some View {
        frame(maxWidth: 600, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
