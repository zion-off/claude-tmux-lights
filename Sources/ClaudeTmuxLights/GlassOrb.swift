import SwiftUI

struct GlassBloom: View {
    let look: Look
    let lit: LampPalette?
    let rim: LampPalette?
    let pulse: Double

    private let diameter = Metrics.lampSize
    private let reach = Throb(steady: 21, base: 22, swing: 8)
    private let opacity = Throb(steady: 0.38, base: 0.25, swing: 0.4)

    var body: some View {
        if let lit {
            let waiting = look == .waiting
            let radius = CGFloat(reach.value(waiting: waiting, pulse: pulse))
            Circle()
                .fill(RadialGradient(stops: falloffStops(lit.bloom), center: .center, startRadius: diameter * 0.42, endRadius: radius))
                .frame(width: radius * 2, height: radius * 2)
                .offset(y: 1)
                .opacity(opacity.value(waiting: waiting, pulse: pulse))
        } else if let rim {
            RimHalo(rim: rim)
        }
    }
}

struct GlassBead: View {
    let look: Look
    let lit: LampPalette?
    let rim: LampPalette?
    let theme: PanelTheme
    let pulse: Double

    private let diameter = Metrics.lampSize

    var body: some View {
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
        .overlay { rimStroke }
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

    @ViewBuilder private var rimStroke: some View {
        if let rim {
            ZStack {
                RimSpill(rim: rim)
                Circle().strokeBorder(LinearGradient(colors: [rim.top, rim.bottom], startPoint: .top, endPoint: .bottom), lineWidth: 1.8)
                Circle().strokeBorder(.black.opacity(0.22), lineWidth: 0.5)
            }
        } else {
            glassRim
        }
    }

    private var glassRim: some View {
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
