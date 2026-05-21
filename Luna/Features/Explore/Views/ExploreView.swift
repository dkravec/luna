import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var appState: LunaAppState
    @StateObject private var viewModel = ExploreViewModel()
    @State private var guidedTourBodyID: String?
    @State private var selectedCollection: ExploreCollection?
    @State private var selectedBodyID: String?

    private enum ScrollAnchor {
        static let categorySection = "explore.categories"
        static let guidedBodySection = "explore.guidedBody"
    }

    var body: some View {
        ScrollViewReader { proxy in
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
                    guidedTourBodySection
                    bodiesSection
                }
                .screenContentPadding()
            }
            .appBackground()
            .background(hiddenNavigationLinks)
            .onAppear {
                viewModel.configure(repository: appState.celestialBodyRepository)
                openRequestedGuidedTourCollectionIfNeeded()
                openRequestedGuidedTourBodyIfNeeded()
                scrollForGuidedTourStep(appState.guidedTourStep, proxy: proxy)
            }
            .onChange(of: appState.guidedTourCollectionID) { _ in
                openRequestedGuidedTourCollectionIfNeeded()
            }
            .onChange(of: appState.guidedTourBodyID) { _ in
                openRequestedGuidedTourBodyIfNeeded()
            }
            .onChange(of: viewModel.loadState) { _ in
                openRequestedGuidedTourCollectionIfNeeded()
                openRequestedGuidedTourBodyIfNeeded()
            }
            .onChange(of: appState.guidedTourStep) { step in
                scrollForGuidedTourStep(step, proxy: proxy)
            }
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
    private var hiddenNavigationLinks: some View {
        hiddenGuidedTourNavigationLink
        hiddenCollectionNavigationLink
        hiddenBodyNavigationLink
    }

    @ViewBuilder
    private var hiddenGuidedTourNavigationLink: some View {
        NavigationLink(
            destination: guidedTourDestination,
            isActive: Binding(
                get: { guidedTourBodyID != nil && selectedCollection == nil },
                set: { isActive in
                    if !isActive {
                        guidedTourBodyID = nil
                    }
                }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    @ViewBuilder
    private var hiddenCollectionNavigationLink: some View {
        NavigationLink(
            destination: selectedCollectionDestination,
            isActive: Binding(
                get: { selectedCollection != nil },
                set: { isActive in
                    if !isActive {
                        selectedCollection = nil
                    }
                }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    @ViewBuilder
    private var hiddenBodyNavigationLink: some View {
        NavigationLink(
            destination: selectedBodyDestination,
            isActive: Binding(
                get: { selectedBodyID != nil },
                set: { isActive in
                    if !isActive {
                        selectedBodyID = nil
                    }
                }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    @ViewBuilder
    private var guidedTourDestination: some View {
        if let bodyID = guidedTourBodyID, let body = body(withID: bodyID) {
            BodyDetailView(
                celestialBody: body,
                childBodies: viewModel.children(of: body),
                allBodies: viewModel.bodies
            )
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var selectedCollectionDestination: some View {
        if let selectedCollection {
            CategoryExploreView(
                collection: selectedCollection,
                bodies: viewModel.bodies(in: selectedCollection),
                allBodies: viewModel.bodies,
                childrenProvider: viewModel.children(of:)
            )
            .environmentObject(appState)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var selectedBodyDestination: some View {
        if let selectedBodyID, let body = body(withID: selectedBodyID) {
            BodyDetailView(
                celestialBody: body,
                childBodies: viewModel.children(of: body),
                allBodies: viewModel.bodies
            )
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var guidedTourBodySection: some View {
        if appState.guidedTourStep == .exploreBody,
           appState.guidedTourCollectionID == nil,
           let body = appState.defaultBodyForGuidedTour() {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Start Here", subtitle: "Open one body to see how Luna connects facts to the experience.")

                bodyLink(for: body)
                    .guidedTourTarget(.exploreBody)
            }
            .id(ScrollAnchor.guidedBodySection)
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
            SectionHeader(title: "Collections")

            LazyVStack(spacing: 10) {
                ForEach(viewModel.exploreCollections) { collection in
                    Button {
                        _ = appState.guidedTourTargetTapped(.exploreCategory)
                        selectedCollection = collection
                    } label: {
                        CategoryCard(
                            collection: collection,
                            itemCount: viewModel.bodyCount(in: collection)
                        )
                    }
                    .buttonStyle(.plain)
                    .hapticTap()
                    .guidedTourTarget(
                        .exploreCategory,
                        when: appState.guidedTourStep == .exploreCategories
                            && collection == guidedTourCollectionFallback
                    )
                }
            }
        }
        .id(ScrollAnchor.categorySection)
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
                            .guidedTourTarget(.exploreBody, when: shouldHighlightBodyForGuidedTour(body))
                    }
                }
            }
        }
    }

    private func bodyLink(for body: CelestialBody) -> some View {
        Button {
            if !appState.guidedTourTargetTapped(.exploreBody) {
                selectedBodyID = body.id
            }
        } label: {
            BodyCard(celestialBody: body)
        }
        .buttonStyle(.plain)
        .hapticTap()
    }

    private var guidedTourCollectionFallback: ExploreCollection? {
        appState.defaultCollectionForGuidedTour() ?? viewModel.exploreCollections.first
    }

    private func shouldHighlightBodyForGuidedTour(_ body: CelestialBody) -> Bool {
        appState.guidedTourStep == .exploreBody
            && body.id == appState.defaultBodyForGuidedTour()?.id
    }

    private func openRequestedGuidedTourCollectionIfNeeded() {
        guard let collectionID = appState.guidedTourCollectionID,
              let collection = ExploreCollection(rawValue: collectionID),
              viewModel.exploreCollections.contains(collection)
        else {
            if appState.guidedTourCollectionID == nil {
                selectedCollection = nil
            }
            return
        }

        if selectedCollection != collection {
            selectedCollection = collection
        }
    }

    private func openRequestedGuidedTourBodyIfNeeded() {
        guard let bodyID = appState.guidedTourBodyID else {
            guidedTourBodyID = nil
            return
        }

        let body = viewModel.bodies.first { $0.id == bodyID }
            ?? appState.celestialBodies.first { $0.id == bodyID }
            ?? appState.defaultBodyForGuidedTour()

        if guidedTourBodyID != body?.id {
            guidedTourBodyID = body?.id
        }
    }

    private func body(withID bodyID: String) -> CelestialBody? {
        viewModel.bodies.first { $0.id == bodyID }
            ?? appState.celestialBodies.first { $0.id == bodyID }
    }

    private func scrollForGuidedTourStep(_ step: GuidedTourStep?, proxy: ScrollViewProxy) {
        guard let step else { return }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                switch step {
                case .exploreCategories:
                    proxy.scrollTo(ScrollAnchor.categorySection, anchor: .top)
                case .exploreBody:
                    proxy.scrollTo(ScrollAnchor.guidedBodySection, anchor: .center)
                default:
                    break
                }
            }
        }
    }

}

private struct CategoryExploreView: View {
    @EnvironmentObject private var appState: LunaAppState

    let collection: ExploreCollection
    let bodies: [CelestialBody]
    let allBodies: [CelestialBody]
    let childrenProvider: (CelestialBody) -> [CelestialBody]

    @State private var searchText = ""
    @State private var selectedBodyID: String?

    private var filteredBodies: [CelestialBody] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return bodies }

        return bodies.filter {
            $0.searchTokens(includeCollectionTokens: false)
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
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
                                    Button {
                                        if !appState.guidedTourTargetTapped(.exploreBody) {
                                            selectedBodyID = body.id
                                        }
                                    } label: {
                                        BodyCard(celestialBody: body)
                                    }
                                    .buttonStyle(.plain)
                                    .hapticTap()
                                    .guidedTourTarget(
                                        .exploreBody,
                                        when: appState.guidedTourStep == .exploreBody
                                            && body.id == appState.defaultBodyForGuidedTour()?.id
                                    )
                                }
                            }
                        }
                    }
                    .id("category.models")
                }
                .screenContentPadding()
            }
            .background(hiddenBodyNavigationLink)
            .onAppear {
                openRequestedGuidedTourBodyIfNeeded()
                scrollForGuidedTourStep(appState.guidedTourStep, proxy: proxy)
            }
            .onChange(of: appState.guidedTourBodyID) { _ in
                openRequestedGuidedTourBodyIfNeeded()
            }
            .onChange(of: appState.guidedTourStep) { step in
                scrollForGuidedTourStep(step, proxy: proxy)
            }
        }
        .appBackground()
        .navigationTitle(collection.title)
    }

    @ViewBuilder
    private var hiddenBodyNavigationLink: some View {
        NavigationLink(
            destination: selectedBodyDestination,
            isActive: Binding(
                get: { selectedBodyID != nil },
                set: { isActive in
                    if !isActive {
                        selectedBodyID = nil
                    }
                }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    @ViewBuilder
    private var selectedBodyDestination: some View {
        if let selectedBodyID, let body = bodies.first(where: { $0.id == selectedBodyID }) {
            BodyDetailView(
                celestialBody: body,
                childBodies: childrenProvider(body),
                allBodies: allBodies
            )
        } else {
            EmptyView()
        }
    }

    private func openRequestedGuidedTourBodyIfNeeded() {
        guard let bodyID = appState.guidedTourBodyID else {
            selectedBodyID = nil
            return
        }

        if selectedBodyID != bodyID, bodies.contains(where: { $0.id == bodyID }) {
            selectedBodyID = bodyID
        }
    }

    private func scrollForGuidedTourStep(_ step: GuidedTourStep?, proxy: ScrollViewProxy) {
        guard step == .exploreBody else { return }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo("category.models", anchor: .center)
            }
        }
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
