import SwiftUI

// Each theme's attention burst, drawn on the screen-wide overlay. `progress` runs from 0 to 1 over
// `Burst.duration`, and `maxRadius` is how far the effect may reach from the lamp.

private func ease(_ p: Double) -> Double { 1 - pow(1 - p, 2.2) }

/// Default: a clean pulse. A soft disc of light swells and fades, with one crisp ring riding its edge.
struct SolidBurst: View {
    let color: Color
    let progress: Double
    let maxRadius: CGFloat
    var gentle = false

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
    var gentle = false

    var body: some View {
        ForEach(0..<(gentle ? 2 : 5), id: \.self) { i in
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
    var gentle = false

    var body: some View {
        let p = progress
        if p > 0, p < 1 {
            let fade = pow(1 - p, 1.1)
            let length = 2 * maxRadius * ease(min(1, p * 1.25))
            ZStack {
                ForEach(Array(0..<8).filter { !gentle || $0.isMultiple(of: 2) }, id: \.self) { i in
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
                    .opacity(Burst.flash(p, span: 0.35) * (gentle ? 0.3 : 1))
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
    var gentle = false

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
                ForEach(0..<(gentle ? 1 : 2), id: \.self) { i in
                    Beam()
                        .fill(RadialGradient(
                            colors: [.white.opacity(0.85 * fade), color.opacity(0.7 * fade), color.opacity(0)],
                            center: .center, startRadius: 0, endRadius: reach
                        ))
                        .frame(width: reach * 2, height: reach * 2)
                        .rotationEffect(.degrees(Double(i) * 180))
                }
                .rotationEffect(.degrees((gentle ? 360 : 720) * p - 90))
                Circle()
                    .fill(RadialGradient(colors: [color, .clear], center: .center, startRadius: 0, endRadius: 110))
                    .frame(width: 220, height: 220)
                    .opacity(gentle ? 0 : 0.9 * Burst.flash(p, span: 0.2))
            }
        }
    }
}

/// Fishbowl: a drop hits the water. Round ripples spread out from the lamp while bubbles rise and pop.
struct FishbowlBurst: View {
    let color: Color
    let progress: Double
    let maxRadius: CGFloat
    var gentle = false

    var body: some View {
        ZStack {
            ForEach(0..<(gentle ? 2 : 4), id: \.self) { i in
                ripple((progress - Double(i) * 0.12) / 0.64)
            }
            ForEach(0..<(gentle ? 6 : 14), id: \.self) { i in
                bubble(i)
            }
        }
    }

    @ViewBuilder private func ripple(_ p: Double) -> some View {
        if p > 0, p < 1 {
            let diameter = max(24, 2 * maxRadius * ease(p))
            let fade = pow(1 - p, 1.3)
            Circle()
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.85 * fade), color.opacity(0.45 * fade), .white.opacity(0.3 * fade)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 3 * (1 - p) + 0.8
                )
                .blur(radius: 0.5)
                .frame(width: diameter, height: diameter)
        }
    }

    /// Bubbles rise from the lamp, each at its own pace, drifting sideways as they go.
    @ViewBuilder private func bubble(_ i: Int) -> some View {
        let seed = Double(i)
        let delay = (sin(seed * 12.9898) * 0.5 + 0.5) * 0.3
        let p = (progress - delay) / (1 - 0.3)
        if p > 0, p < 1 {
            let size = 3 + CGFloat(i % 4) * 2
            let x = CGFloat(sin(seed * 7.1)) * maxRadius * 0.45 + CGFloat(sin(p * 9 + seed)) * 3
            let rise = maxRadius * (0.5 + 0.4 * (cos(seed * 3.3) * 0.5 + 0.5)) * pow(p, 0.8)
            Circle()
                .fill(RadialGradient(colors: [color.opacity(0.05), color.opacity(0.3)], center: .center, startRadius: 0, endRadius: size / 2))
                .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 0.8))
                .overlay(alignment: .topLeading) {
                    Circle().fill(.white.opacity(0.9)).frame(width: size * 0.25, height: size * 0.25).padding(size * 0.18)
                }
                .frame(width: size, height: size)
                .offset(x: x, y: -rise)
                .opacity(p > 0.85 ? (1 - p) / 0.15 : 1)
        }
    }
}
