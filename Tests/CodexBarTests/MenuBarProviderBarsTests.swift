import Foundation
import Testing
@testable import CodexBar

struct MenuBarProviderBarsTests {
    @Test
    func `stacked meters keep a fixed top down order inside the icon canvas`() {
        let rects = IconRenderer.providerBarRects(count: 3)

        #expect(rects.count == 3)
        #expect(rects.allSatisfy { $0.x >= 0 && $0.x + $0.width <= IconRenderer.canvasPx })
        #expect(rects.allSatisfy { $0.y >= 0 && $0.y + $0.height <= IconRenderer.canvasPx })
        #expect(Set(rects.map(\.height)).count == 1)
        // Index 0 is the top row: y descends and no two meters touch.
        for (upper, lower) in zip(rects, rects.dropFirst()) {
            #expect(upper.y > lower.y + lower.height)
        }
    }

    @Test
    func `meter count is capped where the bars stop reading`() {
        #expect(IconRenderer.providerBarRects(count: 0).isEmpty)
        #expect(IconRenderer.providerBarRects(count: -1).isEmpty)
        #expect(IconRenderer.providerBarRects(count: 9).count == IconRenderer.providerBarsMaxCount)

        for count in 1...IconRenderer.providerBarsMaxCount {
            let rects = IconRenderer.providerBarRects(count: count)
            #expect(rects.count == count)
            #expect(rects.allSatisfy { $0.height >= 4 })
            #expect(rects.allSatisfy { $0.y >= 0 && $0.y + $0.height <= IconRenderer.canvasPx })
        }
    }

    @Test
    @MainActor
    func `choosing provider bars turns off the styles that would render first`() {
        let settings = testSettingsStore(suiteName: "MenuBarProviderBarsTests-style")

        settings.menuBarIconStyle = .iconAndPercent
        settings.menuBarIconStyle = .providerBars

        #expect(settings.menuBarIconStyle == .providerBars)
        #expect(settings.menuBarShowsProviderBars)
        // The stored-layout path keys off the brand flag and would win before the meters render.
        #expect(!settings.menuBarShowsBrandIconWithPercent)

        settings.menuBarIconStyle = .bars

        #expect(settings.menuBarIconStyle == .bars)
        #expect(!settings.menuBarShowsProviderBars)
    }
}
