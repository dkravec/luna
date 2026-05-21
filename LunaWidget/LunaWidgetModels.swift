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
    let imageData: Data?
}

struct LunaFactEntry: TimelineEntry {
    let date: Date
    let bodyName: String
    let bodyType: String
    let fact: String
    let textureAssetName: String?
    let hasRings: Bool
}

struct LunaSolarOverviewEntry: TimelineEntry {
    let date: Date
    let bodies: [LunaWidgetBody]
}

private struct LunaWidgetDailyContent {
    let body: LunaWidgetBody
    let fact: String
}

struct LunaWidgetDailyContentProvider {
    func content(for date: Date) -> LunaFactEntry {
        guard !LunaWidgetBody.defaults.isEmpty else {
            return LunaFactEntry(
                date: date,
                bodyName: "Luna",
                bodyType: "Space",
                fact: "Luna has daily space facts ready to explore.",
                textureAssetName: nil,
                hasRings: false
            )
        }

        let content = dailyContent(for: date)
        return LunaFactEntry(
            date: date,
            bodyName: content.body.name,
            bodyType: content.body.type,
            fact: content.fact,
            textureAssetName: content.body.textureAssetName,
            hasRings: content.body.hasRings
        )
    }

    private func dailyContent(for date: Date) -> LunaWidgetDailyContent {
        let bodies = LunaWidgetBody.defaults
        let seed = dailySeed(for: date)
        let body = bodies[seed % bodies.count]

        return LunaWidgetDailyContent(
            body: body,
            fact: fact(for: body, seed: seed)
        )
    }

    private func fact(for body: LunaWidgetBody, seed: Int) -> String {
        let facts = [
            "\(body.name) averages \(body.formattedDistance) from the Sun.",
            "\(body.name) completes an orbit in about \(body.formattedPeriod).",
            "\(body.name) is part of Luna's daily space catalog."
        ]

        return facts[seed % facts.count]
    }

    private func dailySeed(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.era, .year, .month, .day], from: date)
        var value = components.era ?? 1
        value = value &* 31 &+ (components.year ?? 0)
        value = value &* 31 &+ (components.month ?? 0)
        value = value &* 31 &+ (components.day ?? 0)
        return abs(value)
    }
}

struct LunaWidgetBody: Identifiable {
    let id: String
    let name: String
    let type: String
    let distanceFromSun: Double
    let orbitalPeriodDays: Double
    let displaySize: CGFloat
    let color: Color
    let textureAssetName: String?
    let hasRings: Bool

    init(
        id: String,
        name: String,
        type: String,
        distanceFromSun: Double,
        orbitalPeriodDays: Double,
        displaySize: CGFloat,
        color: Color,
        textureAssetName: String? = nil,
        hasRings: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.distanceFromSun = distanceFromSun
        self.orbitalPeriodDays = orbitalPeriodDays
        self.displaySize = displaySize
        self.color = color
        self.textureAssetName = textureAssetName
        self.hasRings = hasRings
    }

    var formattedDistance: String {
        if distanceFromSun >= 1_000 {
            return "\(Self.shortNumber(distanceFromSun / 1_000))B km"
        }

        return "\(Self.shortNumber(distanceFromSun))M km"
    }

    var formattedPeriod: String {
        if orbitalPeriodDays >= 365 {
            return "\(Self.shortNumber(orbitalPeriodDays / 365.25)) years"
        }

        return "\(Self.shortNumber(orbitalPeriodDays)) days"
    }

    func angleRadians(on date: Date) -> Double {
        let days = date.timeIntervalSinceReferenceDate / 86_400
        return (days / max(orbitalPeriodDays, 1)).truncatingRemainder(dividingBy: 1) * .pi * 2
    }

    static let defaults = [
        LunaWidgetBody(id: "mercury", name: "Mercury", type: "Planet", distanceFromSun: 57.9, orbitalPeriodDays: 88, displaySize: 5, color: .gray, textureAssetName: "WidgetMercury"),
        LunaWidgetBody(id: "venus", name: "Venus", type: "Planet", distanceFromSun: 108.2, orbitalPeriodDays: 224.7, displaySize: 7, color: .orange, textureAssetName: "WidgetVenus"),
        LunaWidgetBody(id: "earth", name: "Earth", type: "Planet", distanceFromSun: 149.6, orbitalPeriodDays: 365.25, displaySize: 7, color: .blue, textureAssetName: "WidgetEarth"),
        LunaWidgetBody(id: "mars", name: "Mars", type: "Planet", distanceFromSun: 227.9, orbitalPeriodDays: 687, displaySize: 6, color: .red, textureAssetName: "WidgetMars"),
        LunaWidgetBody(id: "jupiter", name: "Jupiter", type: "Planet", distanceFromSun: 778.5, orbitalPeriodDays: 4_332.6, displaySize: 12, color: .brown, textureAssetName: "WidgetJupiter"),
        LunaWidgetBody(id: "saturn", name: "Saturn", type: "Planet", distanceFromSun: 1_433.5, orbitalPeriodDays: 10_759, displaySize: 11, color: .yellow, textureAssetName: "WidgetSaturn", hasRings: true),
        LunaWidgetBody(id: "uranus", name: "Uranus", type: "Planet", distanceFromSun: 2_872.5, orbitalPeriodDays: 30_685, displaySize: 9, color: .cyan, textureAssetName: "WidgetUranus"),
        LunaWidgetBody(id: "neptune", name: "Neptune", type: "Planet", distanceFromSun: 4_495.1, orbitalPeriodDays: 60_189, displaySize: 9, color: .indigo, textureAssetName: "WidgetNeptune")
    ]

    private static func shortNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value >= 10 ? 1 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

enum LunaWidgetAssetProbe {
    static func exists(_ name: String?) -> Bool {
        guard let name else { return false }
#if os(iOS)
        return UIImage(named: name, in: .main, compatibleWith: nil) != nil
#elseif os(macOS)
        return NSImage(named: name) != nil
#else
        return false
#endif
    }
}
