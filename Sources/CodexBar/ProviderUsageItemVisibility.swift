import CodexBarCore
import Foundation

/// Which surface a usage-item selection applies to.
///
/// `shared` is the provider's own menu tab and its Settings preview. `overview` is the merged
/// Overview tab, which may hide further rows on top of the shared selection so the glance view keeps
/// only the limit the user steers by.
enum ProviderUsageItemSurface: Equatable, Sendable {
    case shared
    case overview
}

struct ProviderUsageItemID: Hashable, Sendable {
    private static let metricPrefix = "metric:"

    let rawValue: String

    var metricID: String? {
        self.rawValue.hasPrefix(Self.metricPrefix) ? String(self.rawValue.dropFirst(Self.metricPrefix.count)) : nil
    }

    static let credits = Self(rawValue: "section:credits")
    static let codexResetCredits = Self(rawValue: "section:codex-reset-credits")

    static func metric(_ metricID: String) -> Self {
        Self(rawValue: "\(self.metricPrefix)\(metricID)")
    }
}

struct ProviderUsageItemDescriptor: Identifiable, Equatable, Sendable {
    let id: ProviderUsageItemID
    let title: String
}

extension ProviderUsageItemID {
    /// Label used when the provider is not reporting the item right now, so the settings row still
    /// names something recognizable instead of falling back to a raw storage key.
    func unreportedTitle(for provider: UsageProvider) -> String {
        switch self {
        case .credits: return L("Credits")
        case .codexResetCredits: return L("Limit Reset Credits")
        default:
            guard let metricID = self.metricID else { return self.rawValue }
            if metricID == "claude-routines" {
                return L("Daily Routines")
            }

            let providerPrefix = "\(provider.rawValue)-"
            let displayID = metricID.hasPrefix(providerPrefix)
                ? String(metricID.dropFirst(providerPrefix.count))
                : metricID
            return displayID
                .split(separator: "-")
                .map { component in
                    component.prefix(1).uppercased() + component.dropFirst()
                }
                .joined(separator: " ")
        }
    }
}

extension UsageMenuCardView.Model {
    @MainActor
    var usageItemDescriptors: [ProviderUsageItemDescriptor] {
        var descriptors = self.metrics.map { metric in
            ProviderUsageItemDescriptor(
                id: .metric(metric.id),
                title: UsageMenuCardView.popupMetricTitle(provider: self.provider, metric: metric))
        }
        // Provider-specific by design: Codex reset credits are a non-metric section with their own visibility choice.
        if self.provider == .codex, self.codexResetCredits != nil {
            descriptors.append(ProviderUsageItemDescriptor(
                id: .codexResetCredits,
                title: L("Limit Reset Credits")))
        }
        if self.creditsText != nil {
            descriptors.append(ProviderUsageItemDescriptor(id: .credits, title: L("Credits")))
        }

        var seen = Set<ProviderUsageItemID>()
        return descriptors.filter { seen.insert($0.id).inserted }
    }

    /// `usageItemDescriptors` plus a row for every hidden item the provider stopped reporting.
    ///
    /// A partial refresh, an outage, or a plan change can drop a lane the user hid earlier. Without
    /// these placeholders its checkbox disappears while the selection stays stored, so the only way
    /// back is Restore Defaults, which also discards every other choice.
    @MainActor
    func usageItemDescriptors(includingHidden hiddenItemIDs: Set<ProviderUsageItemID>)
        -> [ProviderUsageItemDescriptor]
    {
        var descriptors = self.usageItemDescriptors
        guard !hiddenItemIDs.isEmpty else { return descriptors }

        let reported = Set(descriptors.map(\.id))
        for itemID in hiddenItemIDs.subtracting(reported).sorted(by: { $0.rawValue < $1.rawValue }) {
            descriptors.append(ProviderUsageItemDescriptor(
                id: itemID,
                title: L("%@ (unavailable)", itemID.unreportedTitle(for: self.provider))))
        }
        return descriptors
    }

    func applyingUsageItemVisibility(hiddenItemIDs: Set<ProviderUsageItemID>) -> Self {
        guard !hiddenItemIDs.isEmpty else { return self }
        var projected = self
        projected.metrics.removeAll { hiddenItemIDs.contains(.metric($0.id)) }
        if hiddenItemIDs.contains(.credits) {
            projected.creditsText = nil
            projected.creditsRemaining = nil
            projected.creditsProgressPercent = nil
            projected.creditsScaleText = nil
            projected.creditsHintText = nil
            projected.creditsHintCopyText = nil
        }
        if hiddenItemIDs.contains(.codexResetCredits) {
            projected.codexResetCredits = nil
        }
        return projected
    }
}

extension SettingsStore {
    /// Items hidden on `surface`. Overview inherits the shared selection and adds its own rows, so a
    /// row the user hid for the provider never reappears in the glance view.
    func hiddenUsageItemIDs(
        for provider: UsageProvider,
        surface: ProviderUsageItemSurface = .shared) -> Set<ProviderUsageItemID>
    {
        let sharedIDs = self.sharedHiddenUsageItemIDs(for: provider)
        switch surface {
        case .shared:
            return sharedIDs
        case .overview:
            return sharedIDs.union(self.overviewOnlyHiddenUsageItemIDs(for: provider))
        }
    }

    /// Rows hidden in Overview while the provider's own tab still shows them. Empty means Overview
    /// follows the shared selection, which is the default for every provider.
    func overviewOnlyHiddenUsageItemIDs(for provider: UsageProvider) -> Set<ProviderUsageItemID> {
        guard let storedIDs = self.providerConfig(for: provider)?.overviewHiddenUsageItemIDs else { return [] }
        return Set(storedIDs.map(ProviderUsageItemID.init(rawValue:)))
    }

    func isUsageItemVisible(
        _ itemID: ProviderUsageItemID,
        for provider: UsageProvider,
        surface: ProviderUsageItemSurface = .shared) -> Bool
    {
        !self.hiddenUsageItemIDs(for: provider, surface: surface).contains(itemID)
    }

    func setUsageItemVisible(
        _ isVisible: Bool,
        itemID: ProviderUsageItemID,
        for provider: UsageProvider,
        surface: ProviderUsageItemSurface = .shared)
    {
        switch surface {
        case .shared:
            var hiddenIDs = self.sharedHiddenUsageItemIDs(for: provider)
            guard Self.apply(isVisible: isVisible, itemID: itemID, to: &hiddenIDs) else { return }
            self.persistHiddenUsageItemIDs(hiddenIDs, for: provider)
            self.updateLegacyUsageVisibility(provider: provider, hiddenItemIDs: hiddenIDs)
        case .overview:
            var hiddenIDs = self.overviewOnlyHiddenUsageItemIDs(for: provider)
            guard Self.apply(isVisible: isVisible, itemID: itemID, to: &hiddenIDs) else { return }
            self.persistOverviewHiddenUsageItemIDs(hiddenIDs.map(\.rawValue).sorted(), for: provider)
        }
    }

    func restoreDefaultUsageItemVisibility(
        for provider: UsageProvider,
        surface: ProviderUsageItemSurface = .shared)
    {
        switch surface {
        case .shared:
            guard !self.sharedHiddenUsageItemIDs(for: provider).isEmpty ||
                self.providerConfig(for: provider)?.hiddenUsageItemIDs == nil
            else { return }

            self.persistHiddenUsageItemIDs([], for: provider)
            self.updateLegacyUsageVisibility(provider: provider, hiddenItemIDs: [])
        case .overview:
            // Nil, not [], so Overview goes back to following the provider's own selection.
            guard self.providerConfig(for: provider)?.overviewHiddenUsageItemIDs != nil else { return }
            self.persistOverviewHiddenUsageItemIDs(nil, for: provider)
        }
    }

    private func sharedHiddenUsageItemIDs(for provider: UsageProvider) -> Set<ProviderUsageItemID> {
        if let storedIDs = self.providerConfig(for: provider)?.hiddenUsageItemIDs {
            return Set(storedIDs.map(ProviderUsageItemID.init(rawValue:)))
        }

        var hiddenIDs = Set<ProviderUsageItemID>()
        // Provider-specific by design: migrate the legacy Codex Spark and Claude Daily Routines visibility toggles.
        if provider == .codex, !self.codexSparkUsageVisible {
            hiddenIDs.insert(.metric("codex-spark"))
            hiddenIDs.insert(.metric("codex-spark-weekly"))
        }
        if provider == .claude, !self.claudeDailyRoutinesUsageVisible {
            hiddenIDs.insert(.metric("claude-routines"))
        }
        return hiddenIDs
    }

    /// Returns false when the selection already matched, so callers skip a no-op write.
    private static func apply(
        isVisible: Bool,
        itemID: ProviderUsageItemID,
        to hiddenIDs: inout Set<ProviderUsageItemID>) -> Bool
    {
        if isVisible {
            return hiddenIDs.remove(itemID) != nil
        }
        return hiddenIDs.insert(itemID).inserted
    }

    private func persistHiddenUsageItemIDs(
        _ hiddenItemIDs: Set<ProviderUsageItemID>,
        for provider: UsageProvider)
    {
        let rawIDs = hiddenItemIDs.map(\.rawValue).sorted()
        self.updateProviderConfig(provider: provider, affectsBackgroundWork: false) { entry in
            entry.hiddenUsageItemIDs = rawIDs
        }
    }

    private func persistOverviewHiddenUsageItemIDs(
        _ rawIDs: [String]?,
        for provider: UsageProvider)
    {
        self.updateProviderConfig(provider: provider, affectsBackgroundWork: false) { entry in
            entry.overviewHiddenUsageItemIDs = rawIDs
        }
    }

    private func updateLegacyUsageVisibility(
        provider: UsageProvider,
        hiddenItemIDs: Set<ProviderUsageItemID>)
    {
        // Provider-specific by design: keep legacy toggles synchronized so downgrades preserve the closest behavior.
        if provider == .codex {
            let sparkIDs: Set<ProviderUsageItemID> = [
                .metric("codex-spark"),
                .metric("codex-spark-weekly"),
            ]
            self.codexSparkUsageVisible = !sparkIDs.isSubset(of: hiddenItemIDs)
        }
        if provider == .claude {
            self.claudeDailyRoutinesUsageVisible = !hiddenItemIDs.contains(.metric("claude-routines"))
        }
    }
}
