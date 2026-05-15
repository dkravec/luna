import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var appState: LunaAppState
    @StateObject private var viewModel = ExploreViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.section) {
                PageHeader(
                    title: "Explore",
                    subtitle: "Browse worlds, compare facts, and open details from Luna's space library."
                )

                regionSection
                filterSection
                bodiesSection
            }
            .screenContentPadding()
        }
        .appBackground()
        .onAppear {
            viewModel.configure(repository: appState.celestialBodyRepository)
        }
    }

    private var regionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Region")

            CardSection {
                CardRow {
                    RowLabel(
                        title: "Solar System",
                        subtitle: "The Sun, planets, Earth's Moon, and selected satellites",
                        systemImage: "sun.max",
                        value: "Active"
                    )
                }
            }
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Filter", subtitle: "\(viewModel.bodyCountText) bodies shown")

            Card {
                Picker("Body Type", selection: $viewModel.selectedFilter) {
                    ForEach(BodyFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    @ViewBuilder
    private var bodiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Bodies")

            switch viewModel.loadState {
            case .idle:
                EmptyStateView(
                    title: "Loading Bodies",
                    systemImage: "circle.grid.cross",
                    message: "Luna is reading the local solar system library."
                )
            case .failed(let message):
                EmptyStateView(
                    title: "Unable To Load",
                    systemImage: "exclamationmark.triangle",
                    message: message
                )
            case .loaded:
                if viewModel.filteredBodies.isEmpty {
                    EmptyStateView(
                        title: "No Bodies",
                        systemImage: "line.3.horizontal.decrease",
                        message: "Try a different filter."
                    )
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.filteredBodies) { body in
                            NavigationLink {
                                BodyDetailView(
                                    celestialBody: body,
                                    childBodies: viewModel.children(of: body)
                                )
                            } label: {
                                BodyCard(celestialBody: body)
                            }
                            .buttonStyle(.plain)
                            .hapticTap()
                        }
                    }
                }
            }
        }
    }

}

private struct BodyCard: View {
    let celestialBody: CelestialBody

    var bodyContent: some View {
        Card {
            HStack(alignment: .center, spacing: 14) {
                BodyVisual(celestialBody: celestialBody, size: 70)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(celestialBody.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(celestialBody.type.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06), in: Capsule(style: .continuous))
                    }

                    Text(celestialBody.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        BodyFactPill(title: "Radius", value: CompactBodyFormat.distance(celestialBody.radiusKm))

                        if let distance = celestialBody.averageDistanceFromSunKm {
                            BodyFactPill(title: "Sun", value: CompactBodyFormat.distance(distance))
                        }
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(celestialBody.name), \(celestialBody.type.title)")
    }

    var body: some View {
        bodyContent
    }
}

private struct BodyFactPill: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(.secondary)

            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

private enum CompactBodyFormat {
    static func distance(_ value: Double) -> String {
        if value == 0 {
            return "0 km"
        }

        if value < 1 {
            return "\(formatted(value * 1_000)) m"
        }

        if value >= 1_000_000_000 {
            return "\(formatted(value / 1_000_000_000))B km"
        }

        if value >= 1_000_000 {
            return "\(formatted(value / 1_000_000))M km"
        }

        return "\(formatted(value)) km"
    }

    private static func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value >= 100 ? 0 : 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
