import SwiftUI
import WidgetKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct NASAImageEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let imageFilename: String?
}

struct LunaFactEntry: TimelineEntry {
    let date: Date
    let bodyName: String
    let bodyType: String
    let fact: String
    let textureAssetName: String?
    let thumbnailName: String?
    let hasRings: Bool
}

struct LunaSolarOverviewEntry: TimelineEntry {
    let date: Date
    let bodies: [CelestialBody]
}

struct LunaWidgetDailyContentProvider {
    private let source = LunaWidgetContentSource()

    func content(for date: Date) -> LunaFactEntry {
        let content = source.factContent(for: date)
        return LunaFactEntry(
            date: date,
            bodyName: content.body.name,
            bodyType: content.body.typeTitle,
            fact: content.fact,
            textureAssetName: content.body.textureAssetName,
            thumbnailName: content.body.thumbnailName,
            hasRings: content.body.hasRings
        )
    }
}

extension LunaWidgetBodySnapshot {
    var fallbackColor: Color {
        switch name.lowercased() {
        case "mercury", "moon":
            return .gray
        case "venus", "saturn":
            return .yellow
        case "earth", "uranus", "neptune":
            return .blue
        case "mars":
            return .red
        case "jupiter":
            return .orange
        default:
            return .white.opacity(0.72)
        }
    }
}
