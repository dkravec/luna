import Foundation
import WidgetKit

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
        LunaWidgetDailyContentProvider().content(for: date)
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
