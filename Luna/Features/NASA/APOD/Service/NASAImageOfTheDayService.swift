import Foundation

protocol NASAImageOfTheDayProviding {
    func fetchImageOfTheDay() async throws -> NASAImageOfTheDay
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
        let (data, response) = try await session.data(from: Self.endpoint)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw NASAImageOfTheDayError.unavailable
        }

        return try decoder.decode(NASAImageOfTheDay.self, from: data)
    }

    private static let endpoint = URL(string: "https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY&thumbs=true")!

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
