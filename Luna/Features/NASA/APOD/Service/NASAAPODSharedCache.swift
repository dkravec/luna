import Foundation

enum NASAAPODClient {
    static func endpoint(date: Date? = nil) -> URL {
        var components = URLComponents(string: "https://api.nasa.gov/planetary/apod")!
        var queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "thumbs", value: "true")
        ]

        if let date {
            queryItems.append(URLQueryItem(name: "date", value: dateFormatter.string(from: date)))
        }

        components.queryItems = queryItems
        return components.url!
    }

    static func data(from url: URL, session: URLSession = .shared) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard isSuccessful(response) else {
            throw NASAAPODClientError.unavailable
        }
        return data
    }

    static func imageData(from url: URL, session: URLSession = .shared) async throws -> Data {
        try await data(from: url, session: session)
    }

    static var apiKey: String {
        let configuredKey = Bundle.main.object(forInfoDictionaryKey: "NASA_API_KEY") as? String
        let trimmedKey = configuredKey?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmedKey, !trimmedKey.isEmpty, trimmedKey != "$(NASA_API_KEY)" {
            return trimmedKey
        }

        return "DEMO_KEY"
    }

    private static var dateFormatter: DateFormatter {
        NASAAPODSharedCache.dateFormatter
    }

    private static func isSuccessful(_ response: URLResponse) -> Bool {
        guard let httpResponse = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(httpResponse.statusCode)
    }
}

enum NASAAPODClientError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "NASA's image of the day is unavailable right now."
    }
}

struct NASAAPODSharedRecord: Codable, Hashable {
    let title: String
    let dateString: String
    let explanation: String
    let mediaType: String
    let urlString: String?
    let hdurlString: String?
    let thumbnailURLString: String?
    let copyright: String?
    let imageFilename: String?
    let fetchedAt: Date
}

struct NASAAPODSharedCache {
    static let appGroupIdentifier = "group.net.novapro.Luna"

    private let fileManager: FileManager
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func readLatest() -> NASAAPODSharedRecord? {
        readRecords(from: latestMetadataURL).first
    }

    func readHistory(limit: Int) -> [NASAAPODSharedRecord] {
        Array(readRecords(from: historyMetadataURL).prefix(limit))
    }

    func save(latest record: NASAAPODSharedRecord, history: [NASAAPODSharedRecord]) throws {
        try createCacheDirectoriesIfNeeded()
        try write([record], to: latestMetadataURL)
        try write(history, to: historyMetadataURL)
    }

    func imageFileURL(for date: Date) -> URL {
        imageFileURL(forDateString: Self.dateFormatter.string(from: date))
    }

    func imageFileURL(forDateString dateString: String) -> URL {
        imagesDirectoryURL.appendingPathComponent("apod-\(dateString).jpg")
    }

    func createCacheDirectoriesIfNeeded() throws {
        try fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: cacheDirectoryURL.path) else { return }
        try fileManager.removeItem(at: cacheDirectoryURL)
    }

    private func readRecords(from url: URL) -> [NASAAPODSharedRecord] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([NASAAPODSharedRecord].self, from: data)) ?? []
    }

    private func write(_ records: [NASAAPODSharedRecord], to url: URL) throws {
        let data = try encoder.encode(records)
        try data.write(to: url, options: .atomic)
    }

    private var latestMetadataURL: URL {
        cacheDirectoryURL.appendingPathComponent("apod-latest.json")
    }

    private var historyMetadataURL: URL {
        cacheDirectoryURL.appendingPathComponent("apod-history.json")
    }

    private var imagesDirectoryURL: URL {
        cacheDirectoryURL.appendingPathComponent("Images", isDirectory: true)
    }

    private var cacheDirectoryURL: URL {
        containerURL.appendingPathComponent("APOD", isDirectory: true)
    }

    private var containerURL: URL {
        if let url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) {
            return url
        }

        return fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    func imageFileURL(forFilename filename: String) -> URL {
        imagesDirectoryURL.appendingPathComponent(filename)
    }
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
