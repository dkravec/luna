import Foundation

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

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
