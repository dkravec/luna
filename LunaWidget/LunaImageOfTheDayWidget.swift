import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import WidgetKit

struct LunaImageOfTheDayWidget: Widget {
    let kind = "LunaImageOfTheDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NASAImageTimelineProvider()) { entry in
            NASAImageWidgetView(entry: entry)
        }
        .configurationDisplayName("NASA Image")
        .description("See NASA's astronomy image of the day from Luna.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct NASAImageEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let imageData: Data?
}

struct NASAImageTimelineProvider: TimelineProvider {
    private let sharedCache = NASAAPODSharedCache()

    func placeholder(in context: Context) -> NASAImageEntry {
        NASAImageEntry(
            date: Date(),
            title: "Astronomy Image",
            subtitle: "NASA Image of the Day",
            imageData: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NASAImageEntry) -> Void) {
        Task {
            completion(await fetchEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NASAImageEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date().addingTimeInterval(21_600)
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func fetchEntry() async -> NASAImageEntry {
        if let cachedEntry = entryFromSharedCache() {
            return cachedEntry
        }

        do {
            let item = try await NASAImageFetcher.fetch()
            let imageData: Data?
            var imageFilename: String?

            if let imageURL = item.imageURL,
               let fetchedImageData = try? await NASAImageFetcher.fetchImageData(from: imageURL) {
                let imageFileURL = sharedCache.imageFileURL(forDateString: item.dateString)
                try? sharedCache.createCacheDirectoriesIfNeeded()
                try? fetchedImageData.write(to: imageFileURL, options: .atomic)
                imageData = fetchedImageData
                imageFilename = imageFileURL.lastPathComponent
            } else {
                imageData = nil
            }

            let record = item.sharedRecord(imageFilename: imageFilename)
            let existingHistory = sharedCache.readHistory(limit: 30).filter { $0.dateString != record.dateString }
            try? sharedCache.save(latest: record, history: [record] + existingHistory)

            return NASAImageEntry(
                date: Date(),
                title: item.title,
                subtitle: item.subtitle,
                imageData: imageData
            )
        } catch {
            return NASAImageEntry(
                date: Date(),
                title: "NASA Image",
                subtitle: "Check back soon",
                imageData: nil
            )
        }
    }

    private func entryFromSharedCache() -> NASAImageEntry? {
        guard let record = sharedCache.readLatest() else { return nil }
        let imageURL = sharedCache.imageFileURL(forDateString: record.dateString)
        let imageData = try? Data(contentsOf: imageURL)

        return NASAImageEntry(
            date: NASAAPODSharedCache.dateFormatter.date(from: record.dateString) ?? Date(),
            title: record.title,
            subtitle: record.mediaType == "image" ? "NASA Image of the Day" : "NASA Feature",
            imageData: imageData
        )
    }
}

struct NASAImageWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: NASAImageEntry

    var body: some View {
        widgetContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(ContainerRelativeShape())
            .clipped()
            .lunaWidgetBackground()
    }

    private var widgetContent: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                image
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.2), .black.opacity(0.86)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                textBlock
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, bottomPadding)
                    .frame(width: proxy.size.width, alignment: .leading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.subtitle)
                .font(subtitleFont)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(entry.title)
                .font(titleFont)
                .foregroundStyle(.white)
                .lineLimit(titleLineLimit)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
        }
        .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1)
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    private var subtitleFont: Font {
        switch family {
        case .systemLarge:
            return .system(size: 11, weight: .semibold)
        default:
            return .system(size: 10, weight: .semibold)
        }
    }

    private var titleFont: Font {
        switch family {
        case .systemSmall:
            return .system(size: 15, weight: .bold)
        case .systemMedium:
            return .system(size: 17, weight: .bold)
        case .systemLarge:
            return .system(size: 22, weight: .bold)
        default:
            return .headline.weight(.bold)
        }
    }

    private var titleLineLimit: Int {
        switch family {
        case .systemSmall, .systemMedium:
            return 2
        case .systemLarge:
            return 3
        default:
            return 2
        }
    }

    private var horizontalPadding: CGFloat {
        family == .systemSmall ? 12 : 16
    }

    private var bottomPadding: CGFloat {
        family == .systemSmall ? 12 : 16
    }

    @ViewBuilder
    private var image: some View {
        if let imageData = entry.imageData {
#if os(iOS)
            if let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
#elseif os(macOS)
            if let image = NSImage(data: imageData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
#else
            placeholder
#endif
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.12),
                    Color(red: 0.17, green: 0.22, blue: 0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "sparkles")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
    }
}

private struct NASAImageFetcher {
    static func fetch() async throws -> NASAImagePayload {
        var components = URLComponents(string: "https://api.nasa.gov/planetary/apod")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "thumbs", value: "true")
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(NASAImagePayload.self, from: data)
    }

    static func fetchImageData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return data
    }

    private static var apiKey: String {
        let configuredKey = Bundle.main.object(forInfoDictionaryKey: "NASA_API_KEY") as? String
        let trimmedKey = configuredKey?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmedKey, !trimmedKey.isEmpty, trimmedKey != "$(NASA_API_KEY)" {
            return trimmedKey
        }

        return "DEMO_KEY"
    }
}

private struct NASAImagePayload: Decodable {
    let title: String
    let dateString: String
    let explanation: String?
    let mediaType: String
    let url: URL?
    let hdurl: URL?
    let thumbnailURL: URL?
    let copyright: String?

    var imageURL: URL? {
        if mediaType == "image" {
            return url ?? hdurl
        }

        return thumbnailURL
    }

    var subtitle: String {
        mediaType == "image" ? "NASA Image of the Day" : "NASA Feature"
    }

    enum CodingKeys: String, CodingKey {
        case title
        case dateString = "date"
        case explanation
        case mediaType = "media_type"
        case url
        case hdurl
        case thumbnailURL = "thumbnail_url"
        case copyright
    }

    func sharedRecord(imageFilename: String?) -> NASAAPODSharedRecord {
        NASAAPODSharedRecord(
            title: title,
            dateString: dateString,
            explanation: explanation ?? "",
            mediaType: mediaType,
            urlString: url?.absoluteString,
            hdurlString: hdurl?.absoluteString,
            thumbnailURLString: thumbnailURL?.absoluteString,
            copyright: copyright,
            imageFilename: imageFilename,
            fetchedAt: Date()
        )
    }
}

private extension View {
    @ViewBuilder
    func lunaWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, *) {
            containerBackground(for: .widget) {
                Color.black
            }
        } else {
            background(Color.black)
        }
    }
}

@main
struct LunaWidgetBundle: WidgetBundle {
    var body: some Widget {
        LunaImageOfTheDayWidget()
    }
}
