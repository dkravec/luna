import SwiftUI
import UIKit
import WidgetKit

struct LunaImageOfTheDayWidget: Widget {
    let kind = "LunaImageOfTheDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NASAImageTimelineProvider()) { entry in
            NASAImageWidgetView(entry: entry)
        }
        .configurationDisplayName("NASA Image")
        .description("See NASA's astronomy image of the day from Luna.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NASAImageEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let imageData: Data?
}

struct NASAImageTimelineProvider: TimelineProvider {
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
        do {
            let item = try await NASAImageFetcher.fetch()
            let imageData: Data?

            if let imageURL = item.imageURL {
                imageData = try await NASAImageFetcher.fetchImageData(from: imageURL)
            } else {
                imageData = nil
            }

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
}

struct NASAImageWidgetView: View {
    let entry: NASAImageEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let imageData = entry.imageData,
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
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

            LinearGradient(
                colors: [.clear, .black.opacity(0.82)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.subtitle)
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)

                Text(entry.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
            }
            .padding(12)
        }
        .background(Color.black)
    }
}

private struct NASAImageFetcher {
    static func fetch() async throws -> NASAImagePayload {
        let endpoint = URL(string: "https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY&thumbs=true")!
        let (data, response) = try await URLSession.shared.data(from: endpoint)

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
}

private struct NASAImagePayload: Decodable {
    let title: String
    let explanation: String?
    let mediaType: String
    let url: URL?
    let hdurl: URL?
    let thumbnailURL: URL?

    var imageURL: URL? {
        if mediaType == "image" {
            return hdurl ?? url
        }

        return thumbnailURL
    }

    var subtitle: String {
        mediaType == "image" ? "NASA Image of the Day" : "NASA Feature"
    }

    enum CodingKeys: String, CodingKey {
        case title
        case explanation
        case mediaType = "media_type"
        case url
        case hdurl
        case thumbnailURL = "thumbnail_url"
    }
}

@main
struct LunaWidgetBundle: WidgetBundle {
    var body: some Widget {
        LunaImageOfTheDayWidget()
    }
}
