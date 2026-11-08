import SwiftUI

enum Look {
    case waiting, busy, idle, unknown, down

    init(_ status: Status) {
        switch status {
        case .waiting: self = .waiting
        case .busy: self = .busy
        case .idle: self = .idle
        case .unknown: self = .unknown
        }
    }
}

/// Lets the demo generator freeze the pulse at a chosen phase. The app itself never sets it.
private struct PulseOverrideKey: EnvironmentKey {
    static let defaultValue: Double? = nil
}

extension EnvironmentValues {
    var pulseOverride: Double? {
        get { self[PulseOverrideKey.self] }
        set { self[PulseOverrideKey.self] = newValue }
    }
}

/// A value that is steady, or swings with the pulse while a lamp is waiting.
struct Throb {
    let steady: Double
    let base: Double
    let swing: Double

    func value(waiting: Bool, pulse: Double) -> Double {
        waiting ? base + swing * pulse : steady
    }
}

func falloffStops(_ color: Color) -> [Gradient.Stop] {
    [(0.0, 0.95), (0.2, 0.6), (0.4, 0.3), (0.6, 0.13), (0.8, 0.04), (1.0, 0.0)]
        .map { Gradient.Stop(color: color.opacity($0.1), location: $0.0) }
}

struct OrbView: View {
    let look: Look
    let label: String
    let tooltip: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.pulseOverride) private var pulseOverride
    @Environment(\.panelTheme) private var theme

    private var lit: LampPalette? { theme.lamp(for: look) }
    private var legendColor: Color { lit?.legend ?? theme.unlitLegend }

    private static let restingPulse = 0.8

    var body: some View {
        let animates = look == .waiting && !reduceMotion && pulseOverride == nil
        TimelineView(.animation(paused: !animates)) { context in
            let phase = 0.5 + 0.5 * sin(context.date.timeIntervalSinceReferenceDate * 2 * .pi / Motion.pulsePeriod)
            let wave = phase * phase * (3 - 2 * phase)
            lamp(pulse: pulseOverride ?? (animates ? wave : Self.restingPulse))
        }
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }

    private func lamp(pulse: Double) -> some View {
        ZStack {
            lens(pulse: pulse)
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(legendColor)
                .shadow(color: lit == nil ? .clear : legendColor.opacity(0.35), radius: 0.4, y: -0.5)
                .shadow(color: lit == nil ? .clear : .white.opacity(0.32), radius: 0.8, y: 0.9)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(width: Metrics.lampSize - 6)
        }
        .frame(width: Metrics.socketSize, height: Metrics.socketSize)
        .background { bloom(pulse: pulse) }
    }

    @ViewBuilder private func lens(pulse: Double) -> some View {
        switch theme.finish {
        case .solid: SolidLens(look: look, lit: lit, theme: theme, pulse: pulse)
        case .glass: GlassBead(look: look, lit: lit, theme: theme, pulse: pulse)
        }
    }

    @ViewBuilder private func bloom(pulse: Double) -> some View {
        switch theme.finish {
        case .solid: SolidBloom(look: look, lit: lit, pulse: pulse)
        case .glass: GlassBloom(look: look, lit: lit, pulse: pulse)
        }
    }
}
