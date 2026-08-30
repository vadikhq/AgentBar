import SwiftUI
import WidgetKit

@main
struct AgentBarWidgetBundle: WidgetBundle {
    var body: some Widget {
        AgentBarSwitcherWidget()
        AgentBarUsageWidget()
        AgentBarHistoryWidget()
        AgentBarCompactWidget()
        AgentBarBurnDownWidget()
        AgentBarCombinedBurnDownWidget()
    }
}

struct AgentBarSwitcherWidget: Widget {
    private let kind = "AgentBarSwitcherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: self.kind,
            provider: AgentBarSwitcherTimelineProvider())
        { entry in
            AgentBarSwitcherWidgetView(entry: entry)
        }
        .configurationDisplayName("AgentBar Switcher")
        .description("Usage widget with a provider switcher.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct AgentBarUsageWidget: Widget {
    private let kind = "AgentBarUsageWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: ProviderSelectionIntent.self,
            provider: AgentBarTimelineProvider())
        { entry in
            AgentBarUsageWidgetView(entry: entry)
        }
        .configurationDisplayName("AgentBar Usage")
        .description("Session and weekly usage with credits and costs.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct AgentBarHistoryWidget: Widget {
    private let kind = "AgentBarHistoryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: ProviderSelectionIntent.self,
            provider: AgentBarTimelineProvider())
        { entry in
            AgentBarHistoryWidgetView(entry: entry)
        }
        .configurationDisplayName("AgentBar History")
        .description("Usage history chart with recent totals.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct AgentBarCompactWidget: Widget {
    private let kind = "AgentBarCompactWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: CompactMetricSelectionIntent.self,
            provider: AgentBarCompactTimelineProvider())
        { entry in
            AgentBarCompactWidgetView(entry: entry)
        }
        .configurationDisplayName("AgentBar Metric")
        .description("Compact widget for credits or cost.")
        .supportedFamilies([.systemSmall])
    }
}

enum BurnDownWidgetBackgroundConfiguration {
    static let isRemovable = true
}

struct AgentBarBurnDownWidget: Widget {
    private let kind = "AgentBarBurnDownWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: BurnDownSelectionIntent.self,
            provider: BurnDownTimelineProvider())
        { entry in
            BurnDownWidgetView(entry: entry)
        }
        .configurationDisplayName("AgentBar Burn Down")
        .description("Remaining budget compared with an ideal steady burn rate.")
        .supportedFamilies([.systemMedium])
        .containerBackgroundRemovable(BurnDownWidgetBackgroundConfiguration.isRemovable)
    }
}

struct AgentBarCombinedBurnDownWidget: Widget {
    private let kind = "AgentBarCombinedBurnDownWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: BurnProviderSelectionIntent.self,
            provider: CombinedBurnDownTimelineProvider())
        { entry in
            CombinedBurnDownWidgetView(entry: entry)
        }
        .configurationDisplayName("AgentBar Burn Down (Combined)")
        .description("Session and weekly burn-down charts in one tile.")
        .supportedFamilies([.systemMedium])
        .containerBackgroundRemovable(BurnDownWidgetBackgroundConfiguration.isRemovable)
    }
}
