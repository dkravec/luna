import Foundation

struct NASAImageOfTheDay: Decodable, Hashable, Identifiable {
    let title: String
    let date: Date
    let explanation: String
    let mediaType: String
    let url: URL?
    let hdurl: URL?
    let thumbnailURL: URL?
    let copyright: String?
    var cachedImageURL: URL?

    var previewURL: URL? {
        thumbnailURL ?? url ?? hdurl
    }

    var sourceURL: URL? {
        hdurl ?? url
    }

    var isImage: Bool {
        mediaType == "image"
    }

    var id: String {
        let dateString = NASAAPODSharedCache.dateFormatter.string(from: date)
        let source = sourceURL?.absoluteString ?? previewURL?.absoluteString ?? title
        return "\(dateString)-\(mediaType)-\(source)"
    }

    init(
        title: String,
        date: Date,
        explanation: String,
        mediaType: String,
        url: URL?,
        hdurl: URL?,
        thumbnailURL: URL?,
        copyright: String?,
        cachedImageURL: URL? = nil
    ) {
        self.title = title
        self.date = date
        self.explanation = explanation
        self.mediaType = mediaType
        self.url = url
        self.hdurl = hdurl
        self.thumbnailURL = thumbnailURL
        self.copyright = copyright
        self.cachedImageURL = cachedImageURL
    }

    enum CodingKeys: String, CodingKey {
        case title
        case date
        case explanation
        case mediaType = "media_type"
        case url
        case hdurl
        case thumbnailURL = "thumbnail_url"
        case copyright
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        explanation = try container.decode(String.self, forKey: .explanation)
        mediaType = try container.decode(String.self, forKey: .mediaType)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        hdurl = try container.decodeIfPresent(URL.self, forKey: .hdurl)
        thumbnailURL = try container.decodeIfPresent(URL.self, forKey: .thumbnailURL)
        copyright = try container.decodeIfPresent(String.self, forKey: .copyright)
        cachedImageURL = nil
    }
}
