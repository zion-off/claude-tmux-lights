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
    @Environment(\.panelTheme) private var theme

    private var lit: Theme.Lamp? { theme.lamp(for: look) }
    private var legendColor: Color { lit?.legend ?? theme.unlitLegend }

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
            switch theme.finish {
            case .solid: lens(pulse: pulse)
            case .glass: bead(pulse: pulse)
            }
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(legendColor)
                .shadow(color: lit == nil ? .clear : legendColor.opacity(0.35), radius: 0.4, y: -0.5)
                .shadow(color: lit == nil ? .clear : .white.opacity(0.32), radius: 0.8, y: 0.9)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(width: diameter - 6)
        }
        .frame(width: Theme.socketSize, height: Theme.socketSize)
        .background {
            switch theme.finish {
            case .solid: bloom(pulse: pulse)
            case .glass: glassBloom(pulse: pulse)
            }
        }
    }

    private static func falloff(_ color: Color) -> [Gradient.Stop] {
        [(0.0, 0.95), (0.2, 0.6), (0.4, 0.3), (0.6, 0.13), (0.8, 0.04), (1.0, 0.0)]
            .map { Gradient.Stop(color: color.opacity($0.1), location: $0.0) }
    }

    @ViewBuilder private func bloom(pulse: Double) -> some View {
        if let lit {
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
        if let lit {
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
                .fill(theme.unlitLens)
                .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.07), .clear], startPoint: .top, endPoint: .center)))
                .overlay(
                    Circle().strokeBorder(
                        look == .unknown ? theme.unlitLegend.opacity(0.8) : .white.opacity(0.28),
                        style: StrokeStyle(lineWidth: 1.2, dash: look == .unknown ? [2.5, 2.5] : [])
                    )
                )
                .frame(width: diameter, height: diameter)
        }
    }

    // MARK: Glass

    @ViewBuilder private func glassBloom(pulse: Double) -> some View {
        if let lit {
            let waiting = look == .waiting
            let reach: CGFloat = waiting ? 22 + 8 * pulse : 21
            Circle()
                .fill(RadialGradient(stops: Self.falloff(lit.bloom), center: .center, startRadius: diameter * 0.42, endRadius: reach))
                .frame(width: reach * 2, height: reach * 2)
                .offset(y: 1)
                .opacity(waiting ? 0.25 + 0.4 * pulse : 0.38)
        }
    }

    private func bead(pulse: Double) -> some View {
        let shape = Circle()
        return ZStack {
            if let lit {
                // Light from inside: a bright, nearly opaque core that fades to tinted, see-through glass.
                let breath = look == .waiting ? pulse : 0.6
                shape.fill(RadialGradient(
                    stops: [
                        .init(color: lit.top.opacity(0.97), location: 0),
                        .init(color: lit.top.opacity(0.9), location: 0.26 + 0.12 * breath),
                        .init(color: lit.bottom.opacity(0.72 + 0.12 * breath), location: 0.62 + 0.08 * breath),
                        .init(color: lit.bottom.opacity(0.4 + 0.15 * breath), location: 1),
                    ],
                    center: UnitPoint(x: 0.5, y: 0.54),
                    startRadius: 0,
                    endRadius: diameter / 2
                ))
            } else {
                // Clear glass with a smoked core so the gray number reads over any backdrop.
                shape.fill(.white.opacity(0.1))
                shape.fill(RadialGradient(
                    stops: [
                        .init(color: theme.unlitLens, location: 0),
                        .init(color: theme.unlitLens, location: 0.42),
                        .init(color: theme.unlitLens.opacity(0.25), location: 0.85),
                        .init(color: .clear, location: 1),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2
                ))
            }
            caustic
            gloss
        }
        .clipShape(shape)
        .background { beadBase }
        .overlay { rim }
        .overlay { specular }
        .frame(width: diameter, height: diameter)
        .background {
            // Refraction shadow: the bead bends light away from just beneath it.
            shape
                .fill(.black.opacity(lit == nil ? 0.22 : 0.16))
                .frame(width: diameter * 0.9, height: diameter * 0.9)
                .blur(radius: 2)
                .offset(y: 2)
        }
    }

    @ViewBuilder private var beadBase: some View {
        if #available(macOS 26, *) {
            Color.clear.glassEffect(.clear, in: Circle())
        } else {
            Circle().fill(.ultraThinMaterial)
        }
    }

    /// Light gathered at the bottom of the bead, opposite the top highlight.
    private var caustic: some View {
        Ellipse()
            .fill(RadialGradient(
                colors: [(lit?.top ?? .white).opacity(lit == nil ? 0.32 : 0.6), .clear],
                center: .center,
                startRadius: 0,
                endRadius: diameter * 0.3
            ))
            .frame(width: diameter * 0.7, height: diameter * 0.3)
            .offset(y: diameter * 0.36)
    }

    private var gloss: some View {
        Ellipse()
            .fill(LinearGradient(colors: [.white.opacity(lit == nil ? 0.28 : 0.4), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
            .frame(width: diameter * 0.6, height: diameter * 0.26)
            .offset(y: -diameter * 0.3)
    }

    private var rim: some View {
        ZStack {
            Circle().strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.6), location: 0),
                        .init(color: .white.opacity(0.12), location: 0.5),
                        .init(color: .white.opacity(0.32), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                style: StrokeStyle(lineWidth: look == .unknown ? 1.2 : 0.8, dash: look == .unknown ? [2.5, 2.5] : [])
            )
            Circle().strokeBorder(.black.opacity(0.22), lineWidth: 0.5)
            if look == .unknown {
                Circle().strokeBorder(.black.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2.5], dashPhase: 2.5))
            }
        }
    }

    /// A bright arc along the top edge, like a window reflected in the glass.
    private var specular: some View {
        Circle()
            .trim(from: 0.6, to: 0.9)
            .stroke(
                LinearGradient(colors: [.white.opacity(0), .white.opacity(0.95), .white.opacity(0)], startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
            )
            .padding(2.4)
    }
}
