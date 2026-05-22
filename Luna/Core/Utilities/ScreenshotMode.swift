import Foundation

enum ScreenshotScreen: String {
    case arPlacement
    case sceneExperience
    case scaleControls
    case objectDetail
    case apod
    case exploreLibrary
    case home
    case macMainWindow
}

struct ScreenshotMode: Equatable {
    let screen: ScreenshotScreen?

    var isEnabled: Bool {
        screen != nil || ProcessInfo.processInfo.arguments.contains("-screenshotMode")
    }

    static let current = ScreenshotMode(arguments: ProcessInfo.processInfo.arguments)

    init(arguments: [String]) {
        guard arguments.contains("-screenshotMode") else {
            screen = nil
            return
        }

        if let index = arguments.firstIndex(of: "-screenshotScreen"),
           arguments.indices.contains(arguments.index(after: index)) {
            screen = ScreenshotScreen(rawValue: arguments[arguments.index(after: index)])
        } else {
            screen = nil
        }
    }

    static var isEnabled: Bool {
        current.isEnabled
    }

    static var screen: ScreenshotScreen? {
        current.screen
    }

    static var fixedDate: Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 5
        components.day = 21
        components.hour = 12
        return components.date ?? Date(timeIntervalSince1970: 1_779_363_200)
    }

    static var demoAPOD: NASAImageOfTheDay {
        NASAImageOfTheDay(
            title: "A Spiral Galaxy In Moonlight",
            date: fixedDate,
            explanation: "A luminous spiral galaxy stretches across a star-rich field, giving Luna a stable astronomy image for screenshot capture without relying on today's network response.",
            mediaType: "image",
            url: nil,
            hdurl: nil,
            thumbnailURL: nil,
            copyright: "Luna demo"
        )
    }
}
