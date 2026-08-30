import Testing
@testable import AgentBarWidget

struct BurnDownWidgetConfigurationTests {
    @Test
    func `burn down widget background is removable by the system`() {
        #expect(BurnDownWidgetBackgroundConfiguration.isRemovable)
    }
}
