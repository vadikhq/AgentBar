import Foundation
import Testing
@testable import AgentBarCore

struct AgentBarConfigUnknownProviderTests {
    @Test
    func `removed provider entries do not invalidate persisted config`() throws {
        let data = Data(#"""
        {
          "version": 1,
          "providers": [
            {"id": "kimik2", "enabled": true},
            {"id": "crossmodel", "enabled": true},
            {"id": "codex", "enabled": false, "source": "oauth"}
          ]
        }
        """#.utf8)

        let decoded = try JSONDecoder().decode(AgentBarConfig.self, from: data)

        #expect(decoded.providers.map(\.id) == [.codex])
        #expect(decoded.providerConfig(for: .codex)?.enabled == false)
        #expect(decoded.providerConfig(for: .codex)?.source == .oauth)
    }
}
