import AgentBarCore
import Testing
@testable import AgentBar

struct KeychainPromptCoordinatorTests {
    @Test
    func `detects raw SwiftPM debug executable`() {
        #expect(KeychainPromptCoordinator.isUnbundledAgentBarExecutable(
            "/Users/me/AgentBar/.build/arm64-apple-macosx/debug/AgentBar"))
        #expect(KeychainPromptCoordinator.isUnbundledAgentBarExecutable(
            "/Users/me/AgentBar/.build/debug/AgentBar"))
    }

    @Test
    func `detects raw SwiftPM release executable`() {
        #expect(KeychainPromptCoordinator.isUnbundledAgentBarExecutable(
            "/Users/me/AgentBar/.build/arm64-apple-macosx/release/AgentBar"))
    }

    @Test
    func `detects custom SwiftPM scratch path`() {
        #expect(KeychainPromptCoordinator.isUnbundledAgentBarExecutable(
            "/tmp/agentbar-build/arm64-apple-macosx/debug/AgentBar"))
    }

    @Test
    func `keeps packaged app keychain behavior`() {
        #expect(!KeychainPromptCoordinator.isUnbundledAgentBarExecutable(
            "/Applications/AgentBar.app/Contents/MacOS/AgentBar"))
        #expect(!KeychainPromptCoordinator.isUnbundledAgentBarExecutable(
            "/Users/me/AgentBar/.build/package/AgentBar.app/Contents/MacOS/AgentBar"))
    }

    @Test
    func `ignores unrelated executable paths`() {
        #expect(!KeychainPromptCoordinator.isUnbundledAgentBarExecutable(
            "/Users/me/AgentBar/.build/debug/AgentBarCLI"))
        #expect(!KeychainPromptCoordinator.isUnbundledAgentBarExecutable(""))
        #expect(!KeychainPromptCoordinator.isUnbundledAgentBarExecutable("AgentBar"))
    }

    @Test
    func `browser cookie alert explains password handling and opt out`() {
        let model = KeychainPromptCoordinator.browserCookieAlertModel(label: "Chrome Safe Storage")

        #expect(model.title == "Keychain Access Required")
        #expect(model.message.contains("Chrome Safe Storage"))
        #expect(model.message.contains("macOS—not AgentBar—handles any Mac login password entry"))
        #expect(model.message.contains("Settings → Advanced"))
        #expect(model.primaryButtonTitle == "OK")
        #expect(model.learnMoreButtonTitle == "Learn More…")
        #expect(model.documentationURL.hasSuffix("/docs/keychain-prompts.md"))
    }

    @Test
    func `provider alert preserves the requested keychain purpose`() {
        let context = KeychainPromptContext(
            kind: .claudeOAuth,
            service: "Claude Code-credentials",
            account: nil)

        let model = KeychainPromptCoordinator.alertModel(for: context)

        #expect(model.message.contains("Claude Code OAuth token"))
        #expect(model.message.contains("fetch your Claude usage"))
        #expect(model.learnMoreButtonTitle == "Learn More…")
    }
}
