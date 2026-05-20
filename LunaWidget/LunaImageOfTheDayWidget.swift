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
        .description("See NASA's astronomy picture of the day.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct LunaFactOfTheDayWidget: Widget {
    let kind = "LunaFactOfTheDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LunaFactTimelineProvider()) { entry in
            LunaFactWidgetView(entry: entry)
        }
        .configurationDisplayName("Luna Fact")
        .description("See Luna's daily featured body and space fact.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct LunaSolarSystemOverviewWidget: Widget {
    let kind = "LunaSolarSystemOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LunaSolarOverviewTimelineProvider()) { entry in
            LunaSolarOverviewWidgetView(entry: entry)
        }
        .configurationDisplayName("Solar System")
        .description("A daily Luna overview of the inner solar system.")
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

struct LunaFactEntry: TimelineEntry {
    let date: Date
    let bodyName: String
    let bodyType: String
    let fact: String
}

struct LunaSolarOverviewEntry: TimelineEntry {
    let date: Date
    let bodies: [LunaWidgetBody]
}

struct NASAImageTimelineProvider: TimelineProvider {
    private let sharedCache = NASAAPODSharedCache()

    func placeholder(in context: Context) -> NASAImageEntry {
        NASAImageEntry(
            date: Date(),
            title: "Astronomy Image",
            subtitle: "Astronomy Picture of the Day",
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
            subtitle: record.mediaType == "image" ? "Astronomy Picture of the Day" : "NASA Feature",
            imageData: imageData
        )
    }
}

struct LunaFactTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LunaFactEntry {
        LunaFactEntry(date: Date(), bodyName: "Moon", bodyType: "Moon", fact: "The Moon averages 384,400 km from Earth.")
    }

    func getSnapshot(in context: Context, completion: @escaping (LunaFactEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LunaFactEntry>) -> Void) {
        let now = Date()
        let nextUpdate = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
        completion(Timeline(entries: [entry(for: now)], policy: .after(nextUpdate)))
    }

    private func entry(for date: Date) -> LunaFactEntry {
        let content = LunaWidgetDailyContentProvider().content(for: date)
        return LunaFactEntry(date: date, bodyName: content.body.name, bodyType: content.body.type, fact: content.fact)
    }
}

struct LunaSolarOverviewTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LunaSolarOverviewEntry {
        LunaSolarOverviewEntry(date: Date(), bodies: LunaWidgetBody.defaults)
    }

    func getSnapshot(in context: Context, completion: @escaping (LunaSolarOverviewEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LunaSolarOverviewEntry>) -> Void) {
        let now = Date()
        let nextUpdate = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
        completion(Timeline(entries: [entry(for: now)], policy: .after(nextUpdate)))
    }

    private func entry(for date: Date) -> LunaSolarOverviewEntry {
        LunaSolarOverviewEntry(date: date, bodies: LunaWidgetBody.defaults)
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

struct LunaFactWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: LunaFactEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LunaWidgetSpaceBackground()

            VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 10) {
                Label(entry.bodyType, systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)

                Text(entry.bodyName)
                    .font(family == .systemSmall ? .title3.weight(.bold) : .title.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(entry.fact)
                    .font(family == .systemSmall ? .caption.weight(.semibold) : .headline)
                    .foregroundStyle(.white.opacity(0.90))
                    .lineLimit(family == .systemSmall ? 3 : 4)
                    .minimumScaleFactor(0.76)
            }
            .padding(family == .systemSmall ? 14 : 18)
        }
        .lunaWidgetBackground()
    }
}

struct LunaSolarOverviewWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: LunaSolarOverviewEntry

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                LunaWidgetSpaceBackground()

                LunaWidgetOrbitView(bodies: entry.bodies)
                    .padding(family == .systemSmall ? 16 : 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Solar System")
                        .font(family == .systemSmall ? .caption.weight(.bold) : .headline.weight(.bold))
                        .foregroundStyle(.white)

                    Text(entry.date, format: .dateTime.month(.abbreviated).day())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(family == .systemSmall ? 12 : 16)
                .frame(width: proxy.size.width, alignment: .leading)
            }
        }
        .lunaWidgetBackground()
    }
}

private struct LunaWidgetOrbitView: View {
    let bodies: [LunaWidgetBody]

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let maxDistance = bodies.map(\.distanceFromSun).max() ?? 1

            ZStack {
                ForEach(bodies.filter { $0.distanceFromSun > 0 }) { body in
                    let radius = max(12, CGFloat(sqrt(body.distanceFromSun / maxDistance)) * size * 0.42)

                    Circle()
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                        .frame(width: radius * 2, height: radius * 2)
                        .position(center)
                }

                Circle()
                    .fill(.yellow)
                    .frame(width: max(9, size * 0.08), height: max(9, size * 0.08))
                    .position(center)

                ForEach(bodies.filter { $0.distanceFromSun > 0 }) { body in
                    let radius = max(12, CGFloat(sqrt(body.distanceFromSun / maxDistance)) * size * 0.42)
                    let angle = body.angleRadians(on: Date())
                    let point = CGPoint(
                        x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius * 0.72
                    )

                    Circle()
                        .fill(body.color)
                        .frame(width: body.displaySize, height: body.displaySize)
                        .position(point)
                }
            }
        }
    }
}

private struct LunaWidgetSpaceBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.025, blue: 0.055),
                Color(red: 0.10, green: 0.17, blue: 0.30),
                Color(red: 0.02, green: 0.02, blue: 0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct LunaWidgetDailyContent {
    let body: LunaWidgetBody
    let fact: String
}

private struct LunaWidgetDailyContentProvider {
    func content(for date: Date) -> LunaWidgetDailyContent {
        let bodies = LunaWidgetBody.defaults
        let seed = dailySeed(for: date)
        let body = bodies[seed % bodies.count]

        return LunaWidgetDailyContent(
            body: body,
            fact: fact(for: body, seed: seed)
        )
    }

    private func fact(for body: LunaWidgetBody, seed: Int) -> String {
        let facts = [
            "\(body.name) averages \(body.formattedDistance) from the Sun.",
            "\(body.name) completes an orbit in about \(body.formattedPeriod).",
            "\(body.name) is part of Luna's daily space catalog."
        ]

        return facts[seed % facts.count]
    }

    private func dailySeed(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.era, .year, .month, .day], from: date)
        var value = components.era ?? 1
        value = value &* 31 &+ (components.year ?? 0)
        value = value &* 31 &+ (components.month ?? 0)
        value = value &* 31 &+ (components.day ?? 0)
        return abs(value)
    }
}

struct LunaWidgetBody: Identifiable {
    let id: String
    let name: String
    let type: String
    let distanceFromSun: Double
    let orbitalPeriodDays: Double
    let displaySize: CGFloat
    let color: Color

    var formattedDistance: String {
        if distanceFromSun >= 1_000 {
            return "\(Self.shortNumber(distanceFromSun / 1_000))B km"
        }

        return "\(Self.shortNumber(distanceFromSun))M km"
    }

    var formattedPeriod: String {
        if orbitalPeriodDays >= 365 {
            return "\(Self.shortNumber(orbitalPeriodDays / 365.25)) years"
        }

        return "\(Self.shortNumber(orbitalPeriodDays)) days"
    }

    func angleRadians(on date: Date) -> Double {
        let days = date.timeIntervalSinceReferenceDate / 86_400
        return (days / max(orbitalPeriodDays, 1)).truncatingRemainder(dividingBy: 1) * .pi * 2
    }

    static let defaults = [
        LunaWidgetBody(id: "mercury", name: "Mercury", type: "Planet", distanceFromSun: 57.9, orbitalPeriodDays: 88, displaySize: 5, color: .gray),
        LunaWidgetBody(id: "venus", name: "Venus", type: "Planet", distanceFromSun: 108.2, orbitalPeriodDays: 224.7, displaySize: 7, color: .orange),
        LunaWidgetBody(id: "earth", name: "Earth", type: "Planet", distanceFromSun: 149.6, orbitalPeriodDays: 365.25, displaySize: 7, color: .blue),
        LunaWidgetBody(id: "mars", name: "Mars", type: "Planet", distanceFromSun: 227.9, orbitalPeriodDays: 687, displaySize: 6, color: .red),
        LunaWidgetBody(id: "jupiter", name: "Jupiter", type: "Planet", distanceFromSun: 778.5, orbitalPeriodDays: 4_332.6, displaySize: 12, color: .brown),
        LunaWidgetBody(id: "saturn", name: "Saturn", type: "Planet", distanceFromSun: 1_433.5, orbitalPeriodDays: 10_759, displaySize: 11, color: .yellow),
        LunaWidgetBody(id: "uranus", name: "Uranus", type: "Planet", distanceFromSun: 2_872.5, orbitalPeriodDays: 30_685, displaySize: 9, color: .cyan),
        LunaWidgetBody(id: "neptune", name: "Neptune", type: "Planet", distanceFromSun: 4_495.1, orbitalPeriodDays: 60_189, displaySize: 9, color: .indigo)
    ]

    private static func shortNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value >= 10 ? 1 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
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
        mediaType == "image" ? "Astronomy Picture of the Day" : "NASA Feature"
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
        LunaFactOfTheDayWidget()
        LunaSolarSystemOverviewWidget()
    }
}
