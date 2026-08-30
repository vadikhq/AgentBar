#if os(Linux)
import Foundation
import Testing
@testable import AgentBarCLI
@testable import AgentBarCore

struct AlibabaTokenPlanLinuxTests {
    @Test
    func `manual cookie source does not require macOS web support`() {
        // The Alibaba/Qwen Token Plan fetch is plain URLSession + cookies, so a manually
        // configured cookie header must be usable off macOS (matches qoder/commandcode).
        #expect(!AgentBarCLI.sourceModeRequiresWebSupport(
            .web,
            provider: .alibabatokenplan,
            settings: ProviderSettingsSnapshot.make(
                alibabaTokenPlan: .init(
                    cookieSource: .manual,
                    manualCookieHeader: "login_qwencloud_ticket=t"))))
    }

    @Test
    func `auto cookie source still requires web support off macOS`() {
        #expect(AgentBarCLI.sourceModeRequiresWebSupport(
            .web,
            provider: .alibabatokenplan,
            settings: ProviderSettingsSnapshot.make(
                alibabaTokenPlan: .init(cookieSource: .auto, manualCookieHeader: nil))))
    }
}
#endif
