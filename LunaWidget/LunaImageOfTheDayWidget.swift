import SwiftUI
import WidgetKit

struct LunaImageOfTheDayWidget: Widget {
    let kind = "LunaImageOfTheDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NASAImageTimelineProvider()) { entry in
            NASAImageWidgetView(entry: entry)
        }
        .configurationDisplayName("NASA Image")
        .description("See NASA's astronomy picture of the day.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct LunaFactOfTheDayWidget: Widget {
    let kind = "LunaFactOfTheDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LunaFactTimelineProvider()) { entry in
            LunaFactWidgetView(entry: entry)
        }
        .configurationDisplayName("Luna Fact")
        .description("See Luna's daily featured body and space fact.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct LunaSolarSystemOverviewWidget: Widget {
    let kind = "LunaSolarSystemOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LunaSolarOverviewTimelineProvider()) { entry in
            LunaSolarOverviewWidgetView(entry: entry)
        }
        .configurationDisplayName("Solar System")
        .description("A daily Luna overview of the inner solar system.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@main
struct LunaWidgetBundle: WidgetBundle {
    var body: some Widget {
        LunaImageOfTheDayWidget()
        LunaFactOfTheDayWidget()
        LunaSolarSystemOverviewWidget()
    }
}
