import AppKit
import Testing
@testable import ClaudeTmuxLights

struct LegendShadeTests {
    private let palettes: [(top: UInt32, bottom: UInt32)] = [(0xFFCB45, 0xFF9F0A), (0x5BAEFF, 0x0A6CFF), (0xFFCF5C, 0xFFA21A), (0x7DBBFF, 0x1F7BFF), (0xFFC24A, 0xE87C00), (0x6FB4FF, 0x0B5ED7)]

    @Test func numeralsReadAgainstTheirLens() {
        for palette in palettes {
            let lens = LegendShade.srgb(LegendShade.average(palette.top, palette.bottom))
            let numeral = LegendShade.nsColor(hue: palette.bottom, against: LegendShade.average(palette.top, palette.bottom))
            #expect(LegendShade.contrastRatio(numeral, lens) >= LegendShade.contrast - 0.01)
        }
    }

    @Test func numeralsKeepTheLampsHue() {
        for palette in palettes {
            let numeral = LegendShade.nsColor(hue: palette.bottom, against: LegendShade.average(palette.top, palette.bottom))
            let lamp = LegendShade.srgb(palette.bottom)
            #expect(abs(numeral.hueComponent - lamp.hueComponent) < 0.02)
        }
    }

    @Test func averageMixesEachChannel() {
        #expect(LegendShade.average(0x000000, 0xFFFFFF) == 0x7F7F7F)
        #expect(LegendShade.average(0xFF0000, 0x00FF00) == 0x7F7F00)
    }
}

struct PanelThemeTests {
    @Test func unknownThemeFallsBackToDefault() {
        #expect(PanelTheme.named("nope").id == PanelTheme.default.id)
        #expect(PanelTheme.named("glass").finish == .glass)
        #expect(PanelTheme.named("jewel").finish == .jewel)
    }

    @Test func themeIDsAreUnique() {
        #expect(Set(PanelTheme.all.map(\.id)).count == PanelTheme.all.count)
    }
}
