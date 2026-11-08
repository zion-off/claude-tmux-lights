import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Layout sizes shared by every theme.
enum Metrics {
    static let lampSize: CGFloat = 34
    static let socketSize: CGFloat = 38
    static let spacing: CGFloat = 6
    static let seamThickness: CGFloat = 1
    static let captionGap: CGFloat = 2
    static let seamLength: CGFloat = 18
    static let padding: CGFloat = 10
    static let glowMargin: CGFloat = 14
}

enum Motion {
    static let pulsePeriod = 1.8
}

struct LampPalette {
    let top: Color
    let bottom: Color
    let bloom: Color
    let haze: Color
    let legend: Color

    init(top: UInt32, bottom: UInt32, bloom: UInt32, haze: UInt32) {
        self.top = Color(hex: top)
        self.bottom = Color(hex: bottom)
        self.bloom = Color(hex: bloom)
        self.haze = Color(hex: haze)
        self.legend = LegendShade.color(hue: bottom, against: LegendShade.average(top, bottom))
    }
}

struct PanelTheme: Identifiable {
    enum Finish {
        /// Opaque lenses in a dark capsule.
        case solid
        /// Translucent beads in a liquid glass capsule.
        case glass
    }

    let id: String
    let name: String
    let finish: Finish
    let waiting: LampPalette
    let busy: LampPalette
    let caseFill: Color
    let unlitLens: Color
    let unlitLegend: Color
    let seam: Color

    static let `default` = PanelTheme(
        id: "default",
        name: "Default",
        finish: .solid,
        waiting: LampPalette(top: 0xFFCB45, bottom: 0xFF9F0A, bloom: 0xFFB000, haze: 0xFF7A00),
        busy: LampPalette(top: 0x5BAEFF, bottom: 0x0A6CFF, bloom: 0x3D8BFF, haze: 0x2B55FF),
        caseFill: Color(hex: 0x0F1013),
        unlitLens: Color(hex: 0x16181D),
        unlitLegend: Color(hex: 0x8A8F99),
        seam: Color.gray.opacity(0.5)
    )

    // Beads are see-through, so the legend sits on a nearly opaque core: a lit tint or dark smoke.
    static let glass = PanelTheme(
        id: "glass",
        name: "Glass",
        finish: .glass,
        waiting: LampPalette(top: 0xFFCF5C, bottom: 0xFFA21A, bloom: 0xFFB52E, haze: 0xFF8A00),
        busy: LampPalette(top: 0x7DBBFF, bottom: 0x1F7BFF, bloom: 0x4C97FF, haze: 0x3366FF),
        caseFill: Color(hex: 0x0F1013),
        unlitLens: Color(hex: 0x16181D).opacity(0.82),
        unlitLegend: Color(hex: 0x8A8F99),
        seam: Color.gray.opacity(0.5)
    )

    static let all = [PanelTheme.default, .glass]

    static func named(_ id: String) -> PanelTheme {
        all.first { $0.id == id } ?? .default
    }

    func lamp(for look: Look) -> LampPalette? {
        switch look {
        case .waiting: waiting
        case .busy: busy
        case .idle, .unknown, .down: nil
        }
    }
}

private struct PanelThemeKey: EnvironmentKey {
    static let defaultValue = PanelTheme.default
}

extension EnvironmentValues {
    var panelTheme: PanelTheme {
        get { self[PanelThemeKey.self] }
        set { self[PanelThemeKey.self] = newValue }
    }
}
