import CoreData
import Foundation
import WidgetKit

protocol NASAImageOfTheDayRepositoryProviding {
    func cachedLatest() throws -> NASAImageOfTheDay?
    func refreshLatest() async throws -> NASAImageOfTheDay
    func savedHistory(limit: Int) throws -> [NASAImageOfTheDay]
    func imageFileURL(for date: Date) -> URL
}

final class NASAImageOfTheDayRepository: NASAImageOfTheDayRepositoryProviding {
    private let context: NSManagedObjectContext
    private let service: NASAImageOfTheDayProviding
    private let sharedCache: NASAAPODSharedCache

    init(
        context: NSManagedObjectContext = LunaPersistenceController.shared.container.viewContext,
        service: NASAImageOfTheDayProviding = NASAImageOfTheDayService(),
        sharedCache: NASAAPODSharedCache = NASAAPODSharedCache()
    ) {
        self.context = context
        self.service = service
        self.sharedCache = sharedCache
    }

    func cachedLatest() throws -> NASAImageOfTheDay? {
        if let latestRecord = try fetchLatestObject() {
            return NASAImageOfTheDay(managedObject: latestRecord, imageFileURL: imageFileURL(for: latestRecord.date ?? Date()))
        }

        guard let sharedRecord = sharedCache.readLatest(),
              let item = NASAImageOfTheDay(sharedRecord: sharedRecord, sharedCache: sharedCache) else {
            return nil
        }

        return item
    }

    func refreshLatest() async throws -> NASAImageOfTheDay {
        var item = try await service.fetchImageOfTheDay()
        try await cacheImageIfNeeded(for: &item)
        try save(item)
        WidgetCenter.shared.reloadAllTimelines()
        return item
    }

    func savedHistory(limit: Int) throws -> [NASAImageOfTheDay] {
        let request = NASAImageOfTheDayRecord.fetchRequest()
        request.fetchLimit = limit
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return try context.fetch(request).map {
            NASAImageOfTheDay(managedObject: $0, imageFileURL: imageFileURL(for: $0.date ?? Date()))
        }
    }

    func imageFileURL(for date: Date) -> URL {
        sharedCache.imageFileURL(for: date)
    }

    private func save(_ item: NASAImageOfTheDay) throws {
        let dateString = NASAAPODSharedCache.dateFormatter.string(from: item.date)
        let object = try fetchObject(dateString: dateString) ?? NASAImageOfTheDayRecord(context: context)
        object.apply(item, dateString: dateString, fetchedAt: Date())
        try saveContextIfNeeded()

        let history = try savedHistory(limit: 30).map { NASAAPODSharedRecord(item: $0) }
        try sharedCache.save(latest: NASAAPODSharedRecord(item: item), history: history)
    }

    private func cacheImageIfNeeded(for item: inout NASAImageOfTheDay) async throws {
        guard item.isImage, let url = item.previewURL else { return }

        let imageURL = imageFileURL(for: item.date)
        try sharedCache.createCacheDirectoriesIfNeeded()
        let data = try await service.fetchImageData(from: url)
        try data.write(to: imageURL, options: .atomic)
        item.cachedImageURL = imageURL
    }

    private func fetchLatestObject() throws -> NASAImageOfTheDayRecord? {
        let request = NASAImageOfTheDayRecord.fetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return try context.fetch(request).first
    }

    private func fetchObject(dateString: String) throws -> NASAImageOfTheDayRecord? {
        let request = NASAImageOfTheDayRecord.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "dateString == %@", dateString)
        return try context.fetch(request).first
    }

    private func saveContextIfNeeded() throws {
        guard context.hasChanges else { return }
        try context.save()
    }
}

extension NASAImageOfTheDay {
    init(managedObject: NASAImageOfTheDayRecord, imageFileURL: URL) {
        self.init(
            title: managedObject.title ?? "NASA Image",
            date: managedObject.date ?? Date(),
            explanation: managedObject.explanationText ?? "",
            mediaType: managedObject.mediaType ?? "image",
            url: managedObject.urlString.flatMap(URL.init(string:)),
            hdurl: managedObject.hdurlString.flatMap(URL.init(string:)),
            thumbnailURL: managedObject.thumbnailURLString.flatMap(URL.init(string:)),
            copyright: managedObject.copyright,
            cachedImageURL: FileManager.default.fileExists(atPath: imageFileURL.path) ? imageFileURL : nil
        )
    }

    init?(sharedRecord: NASAAPODSharedRecord, sharedCache: NASAAPODSharedCache) {
        guard let date = NASAAPODSharedCache.dateFormatter.date(from: sharedRecord.dateString) else {
            return nil
        }

        let imageURL = sharedCache.imageFileURL(forDateString: sharedRecord.dateString)
        self.init(
            title: sharedRecord.title,
            date: date,
            explanation: sharedRecord.explanation,
            mediaType: sharedRecord.mediaType,
            url: sharedRecord.urlString.flatMap(URL.init(string:)),
            hdurl: sharedRecord.hdurlString.flatMap(URL.init(string:)),
            thumbnailURL: sharedRecord.thumbnailURLString.flatMap(URL.init(string:)),
            copyright: sharedRecord.copyright,
            cachedImageURL: FileManager.default.fileExists(atPath: imageURL.path) ? imageURL : nil
        )
    }
}

extension NASAAPODSharedRecord {
    init(item: NASAImageOfTheDay) {
        let dateString = NASAAPODSharedCache.dateFormatter.string(from: item.date)
        self.init(
            title: item.title,
            dateString: dateString,
            explanation: item.explanation,
            mediaType: item.mediaType,
            urlString: item.url?.absoluteString,
            hdurlString: item.hdurl?.absoluteString,
            thumbnailURLString: item.thumbnailURL?.absoluteString,
            copyright: item.copyright,
            imageFilename: "apod-\(dateString).jpg",
            fetchedAt: Date()
        )
    }
}

@objc(NASAImageOfTheDayRecord)
final class NASAImageOfTheDayRecord: NSManagedObject {
    @NSManaged var dateString: String?
    @NSManaged var date: Date?
    @NSManaged var title: String?
    @NSManaged var explanationText: String?
    @NSManaged var mediaType: String?
    @NSManaged var urlString: String?
    @NSManaged var hdurlString: String?
    @NSManaged var thumbnailURLString: String?
    @NSManaged var copyright: String?
    @NSManaged var fetchedAt: Date?
}

extension NASAImageOfTheDayRecord {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<NASAImageOfTheDayRecord> {
        NSFetchRequest<NASAImageOfTheDayRecord>(entityName: "NASAImageOfTheDayRecord")
    }

    func apply(_ item: NASAImageOfTheDay, dateString: String, fetchedAt: Date) {
        self.dateString = dateString
        date = item.date
        title = item.title
        explanationText = item.explanation
        mediaType = item.mediaType
        urlString = item.url?.absoluteString
        hdurlString = item.hdurl?.absoluteString
        thumbnailURLString = item.thumbnailURL?.absoluteString
        copyright = item.copyright
        self.fetchedAt = fetchedAt
    }
}
