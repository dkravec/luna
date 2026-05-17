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
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw NASAImageOfTheDayError.unavailable
        }

        return data
    }

    private func fetchImageOfTheDay(for date: Date?) async throws -> NASAImageOfTheDay {
        let (data, response) = try await session.data(from: Self.endpoint(date: date))

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw NASAImageOfTheDayError.unavailable
        }

        return try decoder.decode(NASAImageOfTheDay.self, from: data)
    }

    private static func endpoint(date: Date?) -> URL {
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

    private static var apiKey: String {
        let configuredKey = Bundle.main.object(forInfoDictionaryKey: "NASA_API_KEY") as? String
        let trimmedKey = configuredKey?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmedKey, !trimmedKey.isEmpty, trimmedKey != "$(NASA_API_KEY)" {
            return trimmedKey
        }

        return "DEMO_KEY"
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
