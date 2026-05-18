import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var appState: LunaAppState
    @StateObject private var viewModel = ExploreViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.section) {
                PageHeader(
                    title: "Explore",
                    subtitle: "Browse worlds, spacecraft, and NASA models from Luna's space library."
                )

                SearchCard(
                    placeholder: "Search Explore",
                    text: $viewModel.searchText
                )
                if viewModel.isSearching {
                    filterSection
                }
                bodiesSection
            }
            .screenContentPadding()
        }
        .appBackground()
        .onAppear {
            viewModel.configure(repository: appState.celestialBodyRepository)
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Filter", subtitle: "\(viewModel.bodyCountText) items shown")

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
        switch viewModel.loadState {
        case .idle:
            EmptyStateView(
                title: "Loading Explore",
                systemImage: "circle.grid.cross",
                message: "Luna is reading the local space library."
            )
        case .failed(let message):
            EmptyStateView(
                title: "Unable To Load",
                systemImage: "exclamationmark.triangle",
                message: message
            )
        case .loaded:
            if viewModel.isSearching {
                searchResultsSection
            } else {
                categorySection
            }
        }
    }

    @ViewBuilder
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Categories")

            LazyVStack(spacing: 10) {
                ForEach(viewModel.exploreCollections) { collection in
                    NavigationLink {
                        CategoryExploreView(
                            collection: collection,
                            bodies: viewModel.bodies(in: collection),
                            childrenProvider: viewModel.children(of:)
                        )
                    } label: {
                        CategoryCard(
                            collection: collection,
                            itemCount: viewModel.bodyCount(in: collection)
                        )
                    }
                    .buttonStyle(.plain)
                    .hapticTap()
                }
            }
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Results")

            if viewModel.filteredBodies.isEmpty {
                EmptyStateView(
                    title: "No Results",
                    systemImage: "line.3.horizontal.decrease",
                    message: "Try another search or filter."
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.filteredBodies) { body in
                        bodyLink(for: body)
                    }
                }
            }
        }
    }

    private func bodyLink(for body: CelestialBody) -> some View {
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

private struct CategoryExploreView: View {
    let collection: ExploreCollection
    let bodies: [CelestialBody]
    let childrenProvider: (CelestialBody) -> [CelestialBody]

    @State private var searchText = ""

    private var filteredBodies: [CelestialBody] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return bodies }

        return bodies.filter {
            $0.searchTokens(includeCollectionTokens: false)
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.section) {
                PageHeader(title: collection.title, subtitle: collection.subtitle)

                SearchCard(
                    placeholder: "Search \(collection.title)",
                    text: $searchText
                )

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Models", subtitle: "\(filteredBodies.count) items shown")

                    if filteredBodies.isEmpty {
                        EmptyStateView(
                            title: "No Results",
                            systemImage: "line.3.horizontal.decrease",
                            message: "Try another search in \(collection.title)."
                        )
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredBodies) { body in
                                NavigationLink {
                                    BodyDetailView(
                                        celestialBody: body,
                                        childBodies: childrenProvider(body)
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
            .screenContentPadding()
        }
        .appBackground()
        .navigationTitle(collection.title)
    }
}

private struct SearchCard: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Search")

            Card {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)

                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .submitLabel(.search)

                    if !text.isEmpty {
                        Button {
                            text = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                        .hapticTap()
                    }
                }
                .accessibilityElement(children: .contain)
            }
        }
    }
}

private struct CategoryCard: View {
    let collection: ExploreCollection
    let itemCount: Int

    var body: some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: collection.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: Radii.rowIcon, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(collection.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(collection.subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Text("\(itemCount)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(collection.title), \(itemCount) items")
    }
}

private struct BodyCard: View {
    let celestialBody: CelestialBody

    var bodyContent: some View {
        Card {
            HStack(alignment: .center, spacing: 14) {
                BodyCardVisual(celestialBody: celestialBody, size: 86)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(celestialBody.name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(celestialBody.type.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06), in: Capsule(style: .continuous))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(celestialBody.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
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

private struct BodyCardVisual: View {
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
        .font(.subheadline.weight(.semibold))
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
