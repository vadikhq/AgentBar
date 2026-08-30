import AgentBarCore
import Foundation

extension Notification.Name {
    static let agentbarDebugBlinkNow = Notification.Name("agentbarDebugBlinkNow")
    #if DEBUG
    static let agentbarDebugSimulateMemoryPressure =
        Notification.Name("com.vadikhq.agentbar.debug.simulateMemoryPressure")
    #endif
    static let agentbarSessionLimitReset = Notification.Name("agentbarSessionLimitReset")
    static let agentbarWeeklyLimitReset = Notification.Name("agentbarWeeklyLimitReset")
    static let agentbarProviderConfigDidChange = Notification.Name("agentbarProviderConfigDidChange")
    static let agentbarLocalConfigFileDidChange = Notification.Name("agentbarLocalConfigFileDidChange")
    static let agentbarUsageSnapshotsDidChange = Notification.Name("agentbarUsageSnapshotsDidChange")
    static let agentbarQuotaWarningDidPost = Notification.Name("agentbarQuotaWarningDidPost")
}

final class UsageSnapshotsDidChangeEvent: NSObject, @unchecked Sendable {
    let snapshots: [AccountSnapshotSyncPayload]

    init(snapshots: [AccountSnapshotSyncPayload]) {
        self.snapshots = snapshots
    }
}

@MainActor
final class SessionLimitResetEvent: NSObject {
    let provider: UsageProvider
    let accountIdentifier: String
    let accountLabel: String?
    let usedPercent: Double

    init(provider: UsageProvider, accountIdentifier: String, accountLabel: String?, usedPercent: Double) {
        self.provider = provider
        self.accountIdentifier = accountIdentifier
        self.accountLabel = accountLabel
        self.usedPercent = usedPercent
    }
}

@MainActor
final class WeeklyLimitResetEvent: NSObject {
    let provider: UsageProvider
    let accountIdentifier: String
    let accountLabel: String?
    let usedPercent: Double

    init(provider: UsageProvider, accountIdentifier: String, accountLabel: String?, usedPercent: Double) {
        self.provider = provider
        self.accountIdentifier = accountIdentifier
        self.accountLabel = accountLabel
        self.usedPercent = usedPercent
    }
}

@MainActor
final class QuotaWarningPostedEvent: NSObject {
    let provider: UsageProvider
    let window: QuotaWarningWindow
    let threshold: Int
    let postedAt: Date

    init(provider: UsageProvider, window: QuotaWarningWindow, threshold: Int, postedAt: Date) {
        self.provider = provider
        self.window = window
        self.threshold = threshold
        self.postedAt = postedAt
    }
}
