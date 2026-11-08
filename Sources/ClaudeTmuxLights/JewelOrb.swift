import SwiftUI

/// Sizes for a faceted lens seated in a chrome bezel, like an indicator lamp on an old control panel.
private enum Jewel {
    static let bezel = Metrics.socketSize - 1
    static let lens = Metrics.lampSize - 4
    /// Where the light falls from: up and to the left.
    static let lightAngle = Angle.degrees(-125)
}

struct JewelBloom: View {
    let look: Look
    let lit: LampPalette?
    let rim: LampPalette?
    let pulse: Double

    // The chrome bezel is opaque, so only a little light escapes past it. Most of the glow, and most
    // of the pulse, lives in the lens and on the bezel's face; a big halo here reads as a backlight.
    private let reach = Throb(steady: 23, base: 22, swing: 4)
    private let opacity = Throb(steady: 0.28, base: 0.18, swing: 0.2)

    var body: some View {
        if let lit {
            let waiting = look == .waiting
            let radius = CGFloat(reach.value(waiting: waiting, pulse: pulse))
            Circle()
                .fill(RadialGradient(stops: falloffStops(lit.bloom), center: .center, startRadius: Jewel.bezel * 0.42, endRadius: radius))
                .frame(width: radius * 2, height: radius * 2)
                .opacity(opacity.value(waiting: waiting, pulse: pulse))
        } else if let rim {
            RimHalo(rim: rim)
        }
    }
}

struct JewelLens: View {
    let look: Look
    let lit: LampPalette?
    let rim: LampPalette?
    let theme: PanelTheme
    let pulse: Double

    private var breath: Double { burn(look, pulse: pulse) }

    var body: some View {
        ZStack {
            bezel
            lens
        }
        .frame(width: Jewel.bezel, height: Jewel.bezel)
    }

    // MARK: Bezel

    private var bezel: some View {
        ZStack {
            // Turned chrome: bands of light and dark that sweep around the ring.
            Circle().fill(AngularGradient(
                stops: [
                    .init(color: Color(hex: 0xE9EBEF), location: 0),
                    .init(color: Color(hex: 0x6A6E77), location: 0.14),
                    .init(color: Color(hex: 0xC4C8CF), location: 0.3),
                    .init(color: Color(hex: 0x4A4D54), location: 0.48),
                    .init(color: Color(hex: 0xA9ADB5), location: 0.62),
                    .init(color: Color(hex: 0x5C6068), location: 0.8),
                    .init(color: Color(hex: 0xE9EBEF), location: 1),
                ],
                center: .center,
                angle: .degrees(-100)
            ))
            Circle().fill(LinearGradient(colors: [.white.opacity(0.28), .black.opacity(0.3)], startPoint: .top, endPoint: .bottom))
            if let lit {
                // Light thrown forward out of the lens onto the chrome face, strongest at the seat.
                Circle()
                    .fill(RadialGradient(
                        stops: [
                            .init(color: lit.bloom.opacity(0.9), location: 0),
                            .init(color: lit.bloom.opacity(0.35), location: 0.45),
                            .init(color: lit.bloom.opacity(0), location: 1),
                        ],
                        center: .center,
                        startRadius: Jewel.lens / 2,
                        endRadius: Jewel.bezel / 2
                    ))
                    .blendMode(.screen)
                    .opacity(0.2 + 0.6 * breath)
            }
            // The lamp's own color catching the inside of the ring.
            if let glow = lit ?? rim {
                Circle()
                    .strokeBorder(glow.bloom.opacity(lit == nil ? 0.35 : 0.3 + 0.4 * breath), lineWidth: 3)
                    .blur(radius: 1.2)
                    .frame(width: Jewel.lens + 4, height: Jewel.lens + 4)
            }
            Circle().strokeBorder(.black.opacity(0.55), lineWidth: 0.6)
            Circle()
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.7), .white.opacity(0)], startPoint: .top, endPoint: .center), lineWidth: 0.6)
                .padding(0.6)
        }
        .frame(width: Jewel.bezel, height: Jewel.bezel)
    }

    // MARK: Lens

    private var lens: some View {
        let shape = Circle()
        return ZStack {
            facets
            if let lit {
                // The bulb behind the glass, brightest at the center and swelling as it burns harder.
                shape.fill(RadialGradient(
                    stops: [
                        .init(color: .white.opacity(0.6 * breath), location: 0),
                        .init(color: lit.top.opacity(0.7 * breath), location: 0.2 + 0.2 * breath),
                        .init(color: lit.top.opacity(0), location: 0.8),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: Jewel.lens / 2
                ))
                .blendMode(.screen)
            }
            // A glint on the upper-left facets.
            Ellipse()
                .fill(RadialGradient(colors: [.white.opacity(lit == nil ? 0.35 : 0.7), .clear], center: .center, startRadius: 0, endRadius: Jewel.lens * 0.16))
                .frame(width: Jewel.lens * 0.34, height: Jewel.lens * 0.22)
                .rotationEffect(.degrees(-40))
                .offset(x: -Jewel.lens * 0.2, y: -Jewel.lens * 0.22)
        }
        .brightness(lit == nil ? 0 : 0.1 * (breath - 0.8))
        .clipShape(shape)
        .overlay { edge }
        .frame(width: Jewel.lens, height: Jewel.lens)
    }

    @ViewBuilder private var edge: some View {
        if let rim {
            ZStack {
                RimSpill(rim: rim)
                Circle().strokeBorder(LinearGradient(colors: [rim.top, rim.bottom], startPoint: .top, endPoint: .bottom), lineWidth: 1.6)
            }
        } else {
            Circle().strokeBorder(
                look == .unknown ? theme.unlitLegend.opacity(0.8) : .black.opacity(0.6),
                style: StrokeStyle(lineWidth: look == .unknown ? 1.2 : 0.8, dash: look == .unknown ? [2.5, 2.5] : [])
            )
        }
    }

    /// A wide octagonal table that holds the numeral, ringed by 24 triangular facets that are each
    /// shaded by how squarely they face the light.
    private var facets: some View {
        let base = lit.map { (top: $0.top, bottom: $0.bottom) }
        let unlit = theme.unlitLens
        // Brighter light inside makes the facets flash harder.
        let highlight = lit == nil ? 0.16 : 0.22 + 0.25 * breath
        let shadow = lit == nil ? 0.45 : 0.32
        return Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = size.width / 2 * 1.08
            let tableRadius = size.width / 2 * 0.64

            func point(_ degrees: Double, _ radius: CGFloat) -> CGPoint {
                let a = Angle.degrees(degrees).radians
                return CGPoint(x: center.x + radius * CGFloat(cos(a)), y: center.y + radius * CGFloat(sin(a)))
            }
            func triangle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Path {
                var path = Path()
                path.addLines([a, b, c])
                path.closeSubpath()
                return path
            }
            func shade(_ path: Path, facing degrees: Double) {
                let light = cos(Angle.degrees(degrees - Jewel.lightAngle.degrees).radians)
                context.fill(path, with: .color(light > 0 ? .white.opacity(highlight * light) : .black.opacity(shadow * -light)))
                context.stroke(path, with: .color(.white.opacity(lit == nil ? 0.06 : 0.14)), lineWidth: 0.4)
            }

            func glass(_ path: Path) {
                if let base {
                    context.fill(path, with: .linearGradient(
                        Gradient(colors: [base.top, base.bottom]),
                        startPoint: CGPoint(x: center.x, y: 0),
                        endPoint: CGPoint(x: center.x, y: size.height)
                    ))
                } else {
                    context.fill(path, with: .color(unlit))
                }
            }

            glass(Path(ellipseIn: CGRect(origin: .zero, size: size)))

            for i in 0..<8 {
                let t0 = Double(i) * 45, t1 = t0 + 45, mid = t0 + 22.5
                let tableNear = point(t0, tableRadius), tableFar = point(t1, tableRadius)
                let rimNear = point(t0, outer), rimMid = point(mid, outer), rimFar = point(t1, outer)
                shade(triangle(tableNear, rimNear, rimMid), facing: t0 + 11)
                shade(triangle(tableNear, tableFar, rimMid), facing: mid + 180)
                shade(triangle(tableFar, rimMid, rimFar), facing: t1 - 11)
            }

            var octagon = Path()
            octagon.addLines((0..<8).map { point(Double($0) * 45, tableRadius) })
            octagon.closeSubpath()
            // The table stays calm behind the numeral, but keeps some depth: the pavilion facets show
            // faintly through it, it swells a little toward the light, and its edges are beveled.
            glass(octagon)
            var table = context
            table.clip(to: octagon)
            let depth = lit == nil ? 0.5 : 1.0
            for i in 0..<16 {
                let a0 = Double(i) * 22.5, a1 = a0 + 22.5
                let facing = cos(Angle.degrees(a0 + 11.25 + 180 - Jewel.lightAngle.degrees).radians)
                let tint: Color = i.isMultiple(of: 2) ? .white.opacity(0.1 * depth * max(facing, 0.3)) : .black.opacity(0.12 * depth)
                table.fill(triangle(center, point(a0, outer), point(a1, outer)), with: .color(tint))
            }
            table.fill(octagon, with: .radialGradient(
                Gradient(colors: [.white.opacity(0.16 * depth), .white.opacity(0), .black.opacity(0.18 * depth)]),
                center: point(Jewel.lightAngle.degrees, tableRadius * 0.35),
                startRadius: 0,
                endRadius: tableRadius * 1.3
            ))
            for i in 0..<8 {
                let a0 = Double(i) * 45, a1 = a0 + 45
                var edge = Path()
                edge.addLines([point(a0, tableRadius), point(a1, tableRadius)])
                let light = cos(Angle.degrees(a0 + 22.5 - Jewel.lightAngle.degrees).radians)
                let color: Color = light > 0 ? .white.opacity((0.12 + 0.4 * light) * depth) : .black.opacity(0.35 * -light * depth + 0.1)
                context.stroke(edge, with: .color(color), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
            }
        }
    }
}
