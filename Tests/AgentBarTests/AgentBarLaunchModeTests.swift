import Testing
@testable import AgentBar

struct AgentBarLaunchModeTests {
    @Test
    func `normal launch starts the application`() {
        #expect(AgentBarLaunchMode.resolve(arguments: ["/Applications/AgentBar"]) == .application)
    }

    @Test
    func `hook event launch skips application initialization`() {
        #expect(AgentBarLaunchMode.resolve(
            arguments: ["/Applications/AgentBar", "--hook-event"]) == .hookEvent)
    }

    @Test
    func `hook event is recognized among other arguments`() {
        #expect(AgentBarLaunchMode.resolve(
            arguments: ["/Applications/AgentBar", "--verbose", "--hook-event"]) == .hookEvent)
    }

    @Test
    func `similar argument still starts the application`() {
        #expect(AgentBarLaunchMode.resolve(
            arguments: ["/Applications/AgentBar", "--hook-events"]) == .application)
    }
}
