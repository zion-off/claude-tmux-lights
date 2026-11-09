import SwiftUI

/// Sizes for an illuminated push button: a concave cap of frosted plastic over a single LED.
enum Frosted {
    static let cap = Metrics.socketSize - 3
}

struct FrostedBloom: View {
    let look: Look
    let lit: LampPalette?
    let rim: LampPalette?
    let pulse: Double
    var burst: Double?

    // The plastic is translucent, so some light leaks onto the panel, but most of it stays in the cap.
    private let reach = Throb(steady: 24, base: 23, swing: 4)
    private let opacity = Throb(steady: 0.34, base: 0.22, swing: 0.22)

    var body: some View {
        if let lit {
            let waiting = look == .waiting
            let radius = CGFloat(reach.value(waiting: waiting, pulse: pulse))
            Circle()
                .fill(RadialGradient(stops: falloffStops(lit.bloom), center: .center, startRadius: Frosted.cap * 0.42, endRadius: radius))
                .frame(width: radius * 2, height: radius * 2)
                .opacity(min(1, opacity.value(waiting: waiting, pulse: pulse) + 0.4 * Burst.flash(burst)))
        }
    }
}

/// Three rings of light leaving a cap one after the other, like a ripple on still water. Drawn by the
/// screen-wide overlay, so `maxRadius` can be as large as the display allows.
struct FrostedRipple: View {
    let color: Color
    let progress: Double
    let maxRadius: CGFloat

    var body: some View {
        ring(progress)
        ring((progress - 0.14) / 0.86)
        ring((progress - 0.28) / 0.72)
    }

    @ViewBuilder private func ring(_ p: Double) -> some View {
        if p > 0, p < 1 {
            let eased = 1 - pow(1 - p, 2.2)
            let fade = pow(1 - p, 1.3)
            let diameter = max(Frosted.cap, 2 * maxRadius * eased)
            ZStack {
                Circle().strokeBorder(color.opacity(0.9 * fade), lineWidth: 14 * (1 - p) + 2)
                    .blur(radius: 5 * (1 - p) + 1)
                Circle().strokeBorder(.white.opacity(0.35 * fade), lineWidth: 2.5 * (1 - p) + 0.6)
            }
            .frame(width: diameter, height: diameter)
        }
    }
}

struct FrostedButton: View {
    let look: Look
    let lit: LampPalette?
    let rim: LampPalette?
    let theme: PanelTheme
    let pulse: Double
    var burst: Double?

    /// How hard the LED is burning. A shell-only wait runs it dimly in the busy color, with no ring to light.
    private var led: (palette: LampPalette, power: Double)? {
        if let lit { return (lit, min(1, max(burn(look, pulse: pulse), Burst.flash(burst)))) }
        if let rim { return (rim, 0.12) }
        return nil
    }

    var body: some View {
        let shape = Circle()
        ZStack {
            if let led {
                // One LED under the middle of the cap. Frosted plastic spreads its light wide and soft,
                // so the whole cap glows, a little brighter toward the middle where the bowl is thinnest.
                shape.fill(led.palette.bottom.opacity(0.5 + 0.5 * led.power))
                    .background(shape.fill(theme.unlitLens))
                shape.fill(RadialGradient(
                    stops: [
                        .init(color: led.palette.top.opacity(0.35 + 0.65 * led.power), location: 0),
                        .init(color: led.palette.top.opacity(0.25 + 0.45 * led.power), location: 0.4),
                        .init(color: led.palette.top.opacity(0), location: 1),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: Frosted.cap / 2
                ))
                shape.fill(RadialGradient(
                    colors: [.white.opacity(0.1 + 0.25 * led.power), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: Frosted.cap * 0.38
                ))
            } else {
                shape.fill(theme.unlitLens)
            }
            // Concave: the bowl's upper wall faces away from the light and its lower wall faces toward it,
            // so the shading rolls smoothly from dark under the top lip to bright low in the bowl.
            shape.fill(LinearGradient(
                stops: [
                    .init(color: .black.opacity(led == nil ? 0.45 : 0.32), location: 0),
                    .init(color: .black.opacity(led == nil ? 0.15 : 0.1), location: 0.3),
                    .init(color: .clear, location: 0.55),
                ],
                startPoint: .top,
                endPoint: .bottom
            ))
            shape
                .stroke(.black.opacity(led == nil ? 0.5 : 0.4), lineWidth: 12)
                .blur(radius: 4.5)
                .offset(y: 3)
            // On a lit cap the lower wall also takes the LED's own color.
            shape
                .fill(RadialGradient(
                    colors: [led.map { $0.palette.top.opacity(0.45) } ?? .white.opacity(0.14), .clear],
                    center: UnitPoint(x: 0.5, y: 0.95),
                    startRadius: 0,
                    endRadius: Frosted.cap * 0.5
                ))
                .blendMode(led == nil ? .normal : .screen)
            // Frosted, stippled plastic: matte, so it scatters light instead of reflecting a sharp highlight.
            Grain(seed: 23, count: 750, light: led == nil ? 0.07 : 0.12, dark: led == nil ? 0.2 : 0.12, size: 0.3)
                .blendMode(led == nil ? .normal : .overlay)
        }
        .clipShape(shape)
        .overlay { edge }
        .frame(width: Frosted.cap, height: Frosted.cap)
        .background {
            // The cap stands a little off the panel and shades it below.
            shape
                .fill(.black.opacity(0.6))
                .blur(radius: 1.4)
                .offset(y: 2)
        }
    }

    /// The cap's outer lip, where the bowl meets the panel.
    @ViewBuilder private var edge: some View {
        if look == .unknown {
            Circle().strokeBorder(theme.unlitLegend.opacity(0.85), style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2.5]))
        } else {
            Circle().strokeBorder(.black.opacity(0.6), lineWidth: 0.6)
        }
    }
}

/// A control panel: a dark textured laminate plate with a fine chamfered edge, like machined plastic.
struct FrostedPanel: View {
    private let cornerRadius: CGFloat = 8

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(Color(hex: 0x121216))
            shape.fill(LinearGradient(colors: [.white.opacity(0.06), .clear, .black.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Grain(seed: 19, count: 1100).clipShape(shape)
            // The chamfer catches light along its top edge and falls into shade along its bottom.
            shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.04), .black.opacity(0.4)], startPoint: .top, endPoint: .bottom),
                lineWidth: 1.2
            )
            shape.strokeBorder(.black.opacity(0.55), lineWidth: 0.5)
        }
    }
}
