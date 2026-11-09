import SwiftUI

// Each theme's attention burst, drawn on the screen-wide overlay. `progress` runs from 0 to 1 over
// `Burst.duration`, and `maxRadius` is how far the effect may reach from the lamp.

private func ease(_ p: Double) -> Double { 1 - pow(1 - p, 2.2) }

/// Default: a clean pulse. A soft disc of light swells and fades, with one crisp ring riding its edge.
struct SolidBurst: View {
    let color: Color
    let progress: Double
    let maxRadius: CGFloat

    var body: some View {
        let p = progress
        if p > 0, p < 1 {
            let diameter = max(24, 2 * maxRadius * ease(p))
            let fade = pow(1 - p, 1.4)
            ZStack {
                Circle().fill(RadialGradient(
                    colors: [color.opacity(0.0), color.opacity(0.35 * fade)],
                    center: .center, startRadius: 0, endRadius: diameter / 2
                ))
                Circle().strokeBorder(color.opacity(0.95 * fade), lineWidth: 6 * (1 - p) + 1.5)
            }
            .frame(width: diameter, height: diameter)
        }
    }
}

/// Glass: thin, clear ripples like drops on water, each with a bright glint along its upper left.
struct GlassBurst: View {
    let color: Color
    let progress: Double
    let maxRadius: CGFloat

    var body: some View {
        ForEach(0..<5, id: \.self) { i in
            ring((progress - Double(i) * 0.1) / (1 - 0.4))
        }
    }

    @ViewBuilder private func ring(_ p: Double) -> some View {
        if p > 0, p < 1 {
            let diameter = max(24, 2 * maxRadius * ease(p))
            let fade = pow(1 - p, 1.2)
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.9 * fade), color.opacity(0.35 * fade), .white.opacity(0.4 * fade)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 4 * (1 - p) + 1
                )
                .blur(radius: 0.6)
                .frame(width: diameter, height: diameter)
        }
    }
}

/// Jewel: a glint. A bright flash at the facet, and a star of rays that lengthens, turns a little and fades.
struct JewelBurst: View {
    let color: Color
    let progress: Double
    let maxRadius: CGFloat

    var body: some View {
        let p = progress
        if p > 0, p < 1 {
            let fade = pow(1 - p, 1.1)
            let length = 2 * maxRadius * ease(min(1, p * 1.25))
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    let long = i.isMultiple(of: 2)
                    let rayLength = max(10, length * (long ? 1 : 0.55))
                    Capsule()
                        .fill(LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: color.opacity(0.85 * fade), location: 0.35),
                                .init(color: .white.opacity(fade), location: 0.5),
                                .init(color: color.opacity(0.85 * fade), location: 0.65),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: (long ? 9 : 5) * (1 - p) + 1.5, height: rayLength)
                        .rotationEffect(.degrees(Double(i) * 22.5))
                }
                Circle()
                    .fill(RadialGradient(colors: [.white, color.opacity(0.7), .clear], center: .center, startRadius: 0, endRadius: 70))
                    .frame(width: 140, height: 140)
                    .opacity(Burst.flash(p, span: 0.35))
                    .scaleEffect(1 + 0.8 * p)
            }
            .rotationEffect(.degrees(30 * p))
            .blur(radius: 0.4)
        }
    }
}

/// Traffic Light: a warning beacon. Two opposite beams sweep around the lamp, twice, as a strobe flashes.
struct SignalBurst: View {
    let color: Color
    let progress: Double
    let maxRadius: CGFloat

    private struct Beam: Shape {
        func path(in rect: CGRect) -> Path {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            var path = Path()
            path.move(to: center)
            path.addArc(center: center, radius: rect.width / 2, startAngle: .degrees(-18), endAngle: .degrees(18), clockwise: false)
            path.closeSubpath()
            return path
        }
    }

    var body: some View {
        let p = progress
        if p > 0, p < 1 {
            let reach = maxRadius * min(1, 0.25 + ease(p * 3))
            let fade = pow(1 - p, 0.8)
            ZStack {
                ForEach(0..<2, id: \.self) { i in
                    Beam()
                        .fill(RadialGradient(
                            colors: [.white.opacity(0.85 * fade), color.opacity(0.7 * fade), color.opacity(0)],
                            center: .center, startRadius: 0, endRadius: reach
                        ))
                        .frame(width: reach * 2, height: reach * 2)
                        .rotationEffect(.degrees(Double(i) * 180))
                }
                .rotationEffect(.degrees(720 * p - 90))
                Circle()
                    .fill(RadialGradient(colors: [color, .clear], center: .center, startRadius: 0, endRadius: 110))
                    .frame(width: 220, height: 220)
                    .opacity(0.9 * Burst.flash(p, span: 0.2))
            }
        }
    }
}
