import Foundation

protocol NASAImageOfTheDayProviding {
    func fetchImageOfTheDay() async throws -> NASAImageOfTheDay
    func fetchImageOfTheDay(date: Date) async throws -> NASAImageOfTheDay
    func fetchImageData(from url: URL) async throws -> Data
}

struct NASAImageOfTheDayService: NASAImageOfTheDayProviding {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(Self.dateFormatter)
        self.decoder = decoder
    }

    func fetchImageOfTheDay() async throws -> NASAImageOfTheDay {
        try await fetchImageOfTheDay(for: nil)
    }

    func fetchImageOfTheDay(date: Date) async throws -> NASAImageOfTheDay {
        try await fetchImageOfTheDay(for: date)
    }

    func fetchImageData(from url: URL) async throws -> Data {
        try await NASAAPODClient.imageData(from: url, session: session)
    }

    private func fetchImageOfTheDay(for date: Date?) async throws -> NASAImageOfTheDay {
        let data = try await NASAAPODClient.data(from: NASAAPODClient.endpoint(date: date), session: session)
        return try decoder.decode(NASAImageOfTheDay.self, from: data)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

enum NASAImageOfTheDayError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "NASA's image of the day is unavailable right now."
    }
}
