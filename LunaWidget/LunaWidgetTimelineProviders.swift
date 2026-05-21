import Foundation
import os
import WidgetKit

struct NASAImageTimelineProvider: TimelineProvider {
    private let sharedCache = NASAAPODSharedCache()
    private let logger = Logger(subsystem: "net.novapro.Luna.widget", category: "APOD")

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

            if let imageURL = item.imageURL {
                do {
                    let fetchedImageData = try await NASAImageFetcher.fetchImageData(from: imageURL)
                    let imageFileURL = sharedCache.imageFileURL(forDateString: item.dateString)
                    try sharedCache.createCacheDirectoriesIfNeeded()
                    try fetchedImageData.write(to: imageFileURL, options: .atomic)
                    imageData = fetchedImageData
                    imageFilename = imageFileURL.lastPathComponent
                } catch {
                    logger.error("APOD widget image fetch/cache failed: \(error.localizedDescription, privacy: .public)")
                    imageData = nil
                }
            } else {
                logger.notice("APOD widget payload did not include an image URL")
                imageData = nil
            }

            let record = item.sharedRecord(imageFilename: imageFilename)
            let existingHistory = sharedCache.readHistory(limit: 30).filter { $0.dateString != record.dateString }
            do {
                try sharedCache.save(latest: record, history: [record] + existingHistory)
            } catch {
                logger.error("APOD widget shared cache save failed: \(error.localizedDescription, privacy: .public)")
            }

            return NASAImageEntry(
                date: Date(),
                title: item.title,
                subtitle: item.subtitle,
                imageData: imageData
            )
        } catch {
            logger.error("APOD widget timeline fetch failed: \(error.localizedDescription, privacy: .public)")
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
        if record.imageFilename != nil, imageData == nil {
            logger.notice("APOD widget shared cache metadata exists but cached image is missing")
        }

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
        LunaFactEntry(
            date: Date(),
            bodyName: "Moon",
            bodyType: "Moon",
            fact: "The Moon averages 384,400 km from Earth.",
            textureAssetName: "WidgetMoon",
            hasRings: false
        )
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
        let data = try await NASAAPODClient.data(from: NASAAPODClient.endpoint())
        let decoder = JSONDecoder()
        return try decoder.decode(NASAImagePayload.self, from: data)
    }

    static func fetchImageData(from url: URL) async throws -> Data {
        try await NASAAPODClient.imageData(from: url)
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
