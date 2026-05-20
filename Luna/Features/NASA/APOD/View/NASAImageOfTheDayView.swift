import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct NASAImageOfTheDayView: View {
    @State private var imageOfTheDayState: NASAImageOfTheDayState = .loading

    private let imageOfTheDayRepository: NASAImageOfTheDayRepositoryProviding

    init(imageOfTheDayRepository: NASAImageOfTheDayRepositoryProviding = NASAImageOfTheDayRepository()) {
        self.imageOfTheDayRepository = imageOfTheDayRepository
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Astronomy Picture of the Day")

            switch imageOfTheDayState {
            case .loading:
                NASAImageOfTheDayLoadingCard()
            case .loaded(let item):
                NavigationLink {
                    NASAImageOfTheDayDetailView(item: item)
                } label: {
                    NASAImageOfTheDayCard(item: item)
                }
                .buttonStyle(.plain)
                .hapticTap()
            case .failed:
                NASAImageOfTheDayUnavailableCard {
                    Task {
                        await loadImageOfTheDay()
                    }
                }
            }
        }
        .task {
            await loadImageOfTheDay()
        }
    }

    @MainActor
    private func loadImageOfTheDay() async {
        do {
            if let cachedItem = try imageOfTheDayRepository.cachedLatest() {
                imageOfTheDayState = .loaded(cachedItem)
            } else {
                imageOfTheDayState = .loading
            }
        } catch {
            imageOfTheDayState = .loading
        }

        do {
            let item = try await imageOfTheDayRepository.refreshLatest()
            imageOfTheDayState = .loaded(item)
        } catch {
            if case .loaded = imageOfTheDayState {
                return
            }

            imageOfTheDayState = .failed
        }
    }
}

private enum NASAImageOfTheDayState: Equatable {
    case loading
    case loaded(NASAImageOfTheDay)
    case failed
}

private struct NASAImageOfTheDayCard: View {
    let item: NASAImageOfTheDay

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            image
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipped()

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 12)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(item.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground())
        .clipShape(RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title). Astronomy Picture of the Day. Opens details.")
    }

    @ViewBuilder
    private var image: some View {
        if let cachedImageURL = item.cachedImageURL {
            LocalNASAImage(url: cachedImageURL)
                .scaledToFill()
        } else if item.isImage, let url = item.previewURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    imagePlaceholder
                        .overlay {
                            ProgressView()
                        }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    imagePlaceholder
                @unknown default:
                    imagePlaceholder
                }
            }
        } else {
            imagePlaceholder
        }
    }

    private var imagePlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Palette.spaceBlack,
                    Palette.orbitBlue.opacity(0.62),
                    Palette.moonGrey.opacity(0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: item.isImage ? "photo" : "play.rectangle")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
        }
    }
}

private struct NASAImageOfTheDayDetailView: View {
    @Environment(\.openURL) private var openURL

    let item: NASAImageOfTheDay
    private let imageOfTheDayRepository: NASAImageOfTheDayRepositoryProviding

    init(
        item: NASAImageOfTheDay,
        imageOfTheDayRepository: NASAImageOfTheDayRepositoryProviding = NASAImageOfTheDayRepository()
    ) {
        self.item = item
        self.imageOfTheDayRepository = imageOfTheDayRepository
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        heroImage
                            .frame(maxHeight: 320)
                            .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(item.date, format: .dateTime.month(.wide).day().year())
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(item.title)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            if let copyright = item.copyright {
                                Label(copyright, systemImage: "camera")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(item.explanation)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if let sourceURL = item.sourceURL {
                    Button {
                        openURL(sourceURL)
                    } label: {
                        Label(item.isImage ? "Open Image" : "Open NASA Feature", systemImage: "safari")
                    }
                    .primaryActionButton()
                }

                NASAImageOfTheDayHistorySection(
                    currentItem: item,
                    imageOfTheDayRepository: imageOfTheDayRepository
                )
            }
            .screenContentPadding()
        }
        .navigationTitle("NASA Image")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .appBackground()
    }

    @ViewBuilder
    private var heroImage: some View {
        if let cachedImageURL = item.cachedImageURL {
            LocalNASAImage(url: cachedImageURL)
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: Radii.tile, style: .continuous))
        } else if item.isImage, let url = item.previewURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    NASAImagePlaceholder(systemImage: "photo")
                        .overlay {
                            ProgressView()
                        }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    NASAImagePlaceholder(systemImage: "photo")
                @unknown default:
                    NASAImagePlaceholder(systemImage: "photo")
                }
            }
        } else {
            NASAImagePlaceholder(systemImage: "play.rectangle")
        }
    }
}

private struct NASAImageOfTheDayHistorySection: View {
    let currentItem: NASAImageOfTheDay
    let imageOfTheDayRepository: NASAImageOfTheDayRepositoryProviding
    @State private var history: [NASAImageOfTheDay] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "History")

            if history.isEmpty {
                Card {
                    Text("Saved APOD entries will appear here after Luna has cached more days.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                CardSection {
                    ForEach(Array(history.enumerated()), id: \.element.id) { index, item in
                        NavigationLink {
                            NASAImageOfTheDayDetailView(item: item, imageOfTheDayRepository: imageOfTheDayRepository)
                        } label: {
                            CardRow {
                                RowLabel(
                                    title: item.title,
                                    subtitle: item.date.formatted(date: .abbreviated, time: .omitted),
                                    systemImage: item.isImage ? "photo" : "play.rectangle",
                                    showsChevron: true
                                )
                            }
                        }
                        .buttonStyle(.plain)

                        if index < history.count - 1 {
                            CardDivider(leadingInset: 56)
                        }
                    }
                }
            }
        }
        .task {
            history = ((try? imageOfTheDayRepository.savedHistory(limit: 12)) ?? [])
                .filter { $0.date != currentItem.date }
        }
    }
}

private struct NASAImageOfTheDayLoadingCard: View {
    var body: some View {
        Card {
            HStack(spacing: 12) {
                ProgressView()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Loading NASA image")
                        .font(.headline)

                    Text("Fetching today's astronomy feature.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct NASAImageOfTheDayUnavailableCard: View {
    let retry: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                RowLabel(
                    title: "Image unavailable",
                    subtitle: "Astronomy picture of the day could not be loaded.",
                    systemImage: "exclamationmark.triangle"
                )

                Button("Try Again", action: retry)
                    .secondaryActionButton()
            }
        }
    }
}

private struct NASAImagePlaceholder: View {
    let systemImage: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Palette.spaceBlack,
                    Palette.orbitBlue.opacity(0.62),
                    Palette.moonGrey.opacity(0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: systemImage)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
        }
    }
}

private struct LocalNASAImage: View {
    let url: URL

    var body: some View {
#if os(iOS)
        if let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
        } else {
            NASAImagePlaceholder(systemImage: "photo")
        }
#elseif os(macOS)
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
        } else {
            NASAImagePlaceholder(systemImage: "photo")
        }
#else
        NASAImagePlaceholder(systemImage: "photo")
#endif
    }
}
