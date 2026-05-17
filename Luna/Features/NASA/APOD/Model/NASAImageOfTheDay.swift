import Foundation

struct NASAImageOfTheDay: Decodable, Hashable, Identifiable {
    let id = UUID()
    let title: String
    let date: Date
    let explanation: String
    let mediaType: String
    let url: URL?
    let hdurl: URL?
    let copyright: String?

    var previewURL: URL? {
        url ?? hdurl
    }

    var sourceURL: URL? {
        hdurl ?? url
    }

    var isImage: Bool {
        mediaType == "image"
    }

    enum CodingKeys: String, CodingKey {
        case title
        case date
        case explanation
        case mediaType = "media_type"
        case url
        case hdurl
        case copyright
    }
}
