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

    var lit: Theme.Lamp? {
        switch self {
        case .waiting: Theme.waiting
        case .busy: Theme.busy
        case .idle, .unknown, .down: nil
        }
    }
}

private struct PulseOverrideKey: EnvironmentKey {
    static let defaultValue: Double? = nil
}

extension EnvironmentValues {
    var pulseOverride: Double? {
        get { self[PulseOverrideKey.self] }
        set { self[PulseOverrideKey.self] = newValue }
    }
}

struct OrbView: View {
    let look: Look
    let label: String
    let tooltip: String

    private var diameter: CGFloat { Theme.lampSize }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.pulseOverride) private var pulseOverride

    private var legendColor: Color { look.lit?.legend ?? Theme.unlitLegend }

    private static let restingPulse = 0.8

    var body: some View {
        let animates = look == .waiting && !reduceMotion && pulseOverride == nil
        TimelineView(.animation(paused: !animates)) { context in
            let phase = 0.5 + 0.5 * sin(context.date.timeIntervalSinceReferenceDate * 2 * .pi / Theme.pulsePeriod)
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
                .shadow(color: look.lit == nil ? .clear : legendColor.opacity(0.35), radius: 0.4, y: -0.5)
                .shadow(color: look.lit == nil ? .clear : .white.opacity(0.32), radius: 0.8, y: 0.9)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(width: diameter - 6)
        }
        .frame(width: Theme.socketSize, height: Theme.socketSize)
        .background { bloom(pulse: pulse) }
    }

    private static func falloff(_ color: Color) -> [Gradient.Stop] {
        [(0.0, 0.95), (0.2, 0.6), (0.4, 0.3), (0.6, 0.13), (0.8, 0.04), (1.0, 0.0)]
            .map { Gradient.Stop(color: color.opacity($0.1), location: $0.0) }
    }

    @ViewBuilder private func bloom(pulse: Double) -> some View {
        if let lit = look.lit {
            let waiting = look == .waiting
            let tight = diameter * (waiting ? 0.9 + 0.2 * pulse : 0.85)
            let haze: CGFloat = waiting ? 28 + 12 * pulse : 24
            ZStack {
                Circle()
                    .fill(RadialGradient(stops: Self.falloff(lit.haze), center: .center, startRadius: diameter * 0.4, endRadius: haze))
                    .frame(width: haze * 2, height: haze * 2)
                    .offset(y: 3)
                    .opacity(waiting ? 0.3 + 0.45 * pulse : 0.4)
                Circle()
                    .fill(RadialGradient(stops: Self.falloff(lit.bloom), center: .center, startRadius: diameter * 0.35, endRadius: tight))
                    .frame(width: tight * 2, height: tight * 2)
                    .opacity(waiting ? 0.5 + 0.4 * pulse : 0.55)
            }
        }
    }

    @ViewBuilder private func lens(pulse: Double) -> some View {
        if let lit = look.lit {
            Circle()
                .fill(LinearGradient(colors: [lit.top, lit.bottom], startPoint: .top, endPoint: .bottom))
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0)], startPoint: .top, endPoint: .center),
                        lineWidth: 1
                    )
                )
                .overlay(Circle().strokeBorder(.black.opacity(0.18), lineWidth: 0.5))
                .brightness(look == .waiting ? 0.05 * pulse : 0)
                .frame(width: diameter, height: diameter)
        } else {
            Circle()
                .fill(Theme.unlitLens)
                .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.07), .clear], startPoint: .top, endPoint: .center)))
                .overlay(
                    Circle().strokeBorder(
                        look == .unknown ? Theme.unlitLegend.opacity(0.8) : .white.opacity(0.28),
                        style: StrokeStyle(lineWidth: 1.2, dash: look == .unknown ? [2.5, 2.5] : [])
                    )
                )
                .frame(width: diameter, height: diameter)
        }
    }
}
