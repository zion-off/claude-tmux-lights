import SwiftUI

/// Sizes for a traffic signal section: a housing with a tunnel visor around a ridged glass lens.
enum Signal {
    static let housing = Metrics.socketSize
    static let visor = Metrics.lampSize
    static let lens = Metrics.lampSize - 6
    /// The lens sits a little low in the visor, so more of the visor's inside shows above it.
    static let lensDrop: CGFloat = 1.5
    /// We look up at a signal, so the hood's open end shows above where it meets the housing.
    static let hoodLift: CGFloat = 1.5
    static let housingColor = Color(hex: 0x1C1D1B)
    static let backplateBorder = Color(hex: 0xF2C200)
}

struct SignalBloom: View {
    let look: Look
    let lit: LampPalette?
    let rim: LampPalette?
    let pulse: Double

    // The housing and visor block most sideways light, so the halo stays small and centered.
    private let reach = Throb(steady: 24, base: 23, swing: 4)
    private let opacity = Throb(steady: 0.3, base: 0.2, swing: 0.2)

    var body: some View {
        if let lit {
            let waiting = look == .waiting
            let radius = CGFloat(reach.value(waiting: waiting, pulse: pulse))
            Circle()
                .fill(RadialGradient(stops: falloffStops(lit.bloom), center: .center, startRadius: Signal.visor * 0.45, endRadius: radius))
                .frame(width: radius * 2, height: radius * 2)
                .opacity(opacity.value(waiting: waiting, pulse: pulse))
        } else if let rim {
            RimHalo(rim: rim)
        }
    }
}

struct SignalLens: View {
    let look: Look
    let lit: LampPalette?
    let rim: LampPalette?
    let theme: PanelTheme
    let pulse: Double

    /// How hard the bulb is burning: it swells and fades while waiting, and holds steady otherwise.
    /// It never drops below a third, so the lamp still reads as lit at the bottom of the pulse.
    private var breath: Double { look == .waiting ? 0.35 + 0.65 * pulse : 0.8 }

    var body: some View {
        ZStack {
            housing
            visor
            lens.offset(y: Signal.lensDrop)
        }
        .frame(width: Signal.housing, height: Signal.housing)
    }

    // MARK: Housing

    private var housing: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        return ZStack {
            shape.fill(Signal.housingColor)
            shape.fill(LinearGradient(colors: [.white.opacity(0.1), .black.opacity(0.25)], startPoint: .top, endPoint: .bottom))
            Grain(seed: 7, count: 260).clipShape(shape)
            shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.03)], startPoint: .top, endPoint: .bottom), lineWidth: 0.8)
            // Paint chipped off the edges, showing lighter metal underneath.
            shape.strokeBorder(Color(hex: 0x6B6A64).opacity(0.5), style: StrokeStyle(lineWidth: 0.9, dash: [0.8, 6, 1.6, 9, 0.6, 4, 2.2, 11]))
            shape.strokeBorder(.black.opacity(0.6), lineWidth: 0.4)
            ForEach(Array(Self.screws.enumerated()), id: \.offset) { index, corner in
                Screw(slant: .degrees(Double(index) * 67 + 20))
                    .position(x: corner.x * Signal.housing, y: corner.y * Signal.housing)
            }
        }
    }

    private static let screwInset: CGFloat = 3.8 / Signal.housing
    private static let screws = [
        CGPoint(x: screwInset, y: screwInset), CGPoint(x: 1 - screwInset, y: screwInset),
        CGPoint(x: screwInset, y: 1 - screwInset), CGPoint(x: 1 - screwInset, y: 1 - screwInset),
    ]

    // MARK: Visor

    /// A cap visor: a hood over the top of the lens, open at the bottom, that casts a shadow on the
    /// housing and catches the lens's light on its inside.
    private var visor: some View {
        let hood = Circle().trim(from: 0, to: 0.68).rotation(.degrees(147))
        let inside = LinearGradient(
            stops: [.init(color: .black, location: 0), .init(color: .black.opacity(0.85), location: 0.55), .init(color: .clear, location: 0.92)],
            startPoint: .top,
            endPoint: .bottom
        )
        return ZStack {
            hood
                .stroke(.black.opacity(0.65), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .padding(1.2)
                .blur(radius: 1.6)
                .offset(y: 2.4 - Signal.hoodLift)
            // The underside of the hood, from its open end down to where it meets the housing.
            Circle().fill(inside).offset(y: -Signal.hoodLift)
            Circle()
                .fill(inside)
                .frame(width: Signal.lens + 4, height: Signal.lens + 4)
                .offset(y: Signal.lensDrop - 1)
            // Dirt that collects where the hood meets the housing.
            Circle()
                .strokeBorder(Color(hex: 0x2A2418).opacity(0.6), lineWidth: 2)
                .blur(radius: 0.8)
                .frame(width: Signal.lens + 5, height: Signal.lens + 5)
                .offset(y: Signal.lensDrop)
                .mask(Circle().fill(inside).offset(y: -Signal.hoodLift))
            if let lit {
                Circle()
                    .fill(RadialGradient(
                        stops: [
                            .init(color: lit.bloom.opacity(0.85), location: 0),
                            .init(color: lit.bloom.opacity(0.3), location: 0.5),
                            .init(color: lit.bloom.opacity(0), location: 1),
                        ],
                        center: UnitPoint(x: 0.5, y: 0.5 + Signal.lensDrop / Signal.visor),
                        startRadius: Signal.lens / 2,
                        endRadius: Signal.visor / 2
                    ))
                    .mask(Circle().fill(inside))
                    .offset(y: -Signal.hoodLift)
                    .blendMode(.screen)
                    .opacity(0.25 + 0.6 * breath)
            }
            // A dark rubber seat where the lens meets the housing.
            Circle()
                .strokeBorder(.black.opacity(0.7), lineWidth: 1.6)
                .frame(width: Signal.lens + 3, height: Signal.lens + 3)
                .offset(y: Signal.lensDrop)
            hood
                .stroke(
                    LinearGradient(colors: [Color(hex: 0x4A4B47), Color(hex: 0x1E1E1D)], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 1.1, lineCap: .round)
                )
                .padding(0.55)
                .offset(y: -Signal.hoodLift)
            hood
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0)], startPoint: .top, endPoint: .center),
                    style: StrokeStyle(lineWidth: 0.7, lineCap: .round)
                )
                .padding(0.4)
                .offset(y: -Signal.hoodLift)
        }
        .frame(width: Signal.visor, height: Signal.visor)
    }

    // MARK: Lens

    private var lens: some View {
        let shape = Circle()
        return ZStack {
            if let lit {
                // The bulb behind the glass, brightest at the center and swelling as it burns harder.
                shape.fill(RadialGradient(
                    stops: [
                        .init(color: .white.opacity(0.35 + 0.5 * breath), location: 0),
                        .init(color: lit.top, location: 0.15 + 0.25 * breath),
                        .init(color: lit.bottom, location: 1),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: Signal.lens / 2
                ))
                .brightness(0.12 * (breath - 0.8))
            } else {
                shape.fill(theme.unlitLens)
            }
            fresnel
            // The visor shades the top of the lens.
            shape.fill(LinearGradient(
                stops: [.init(color: .black.opacity(lit == nil ? 0.5 : 0.35), location: 0), .init(color: .clear, location: 0.38)],
                startPoint: .top,
                endPoint: .bottom
            ))
            // Road dust settled on the lower part of the glass.
            shape.fill(LinearGradient(
                stops: [.init(color: .clear, location: 0.55), .init(color: Color(hex: 0x6B5A3E).opacity(lit == nil ? 0.22 : 0.3), location: 1)],
                startPoint: .top,
                endPoint: .bottom
            ))
            Grain(seed: 3, count: 70, tone: Color(hex: 0x8C7A58)).mask(
                LinearGradient(colors: [.clear, .black], startPoint: .center, endPoint: .bottom)
            )
            // Daylight caught low on the glass, below the visor's shadow.
            Circle()
                .trim(from: 0.1, to: 0.32)
                .stroke(.white.opacity(lit == nil ? 0.22 : 0.35), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                .padding(2.5)
        }
        .clipShape(shape)
        .overlay { edge }
        .frame(width: Signal.lens, height: Signal.lens)
    }

    /// The concentric ridges molded into signal glass to spread the bulb's light.
    private var fresnel: some View {
        let light = lit == nil ? 0.06 : 0.1
        let dark = lit == nil ? 0.22 : 0.1
        return Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            // The middle is left smooth, like the bullseye at the center of signal glass.
            var radius: CGFloat = 5
            while radius < size.width / 2 {
                let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                context.stroke(ring, with: .color(.black.opacity(dark)), lineWidth: 0.6)
                let ridge = Path(ellipseIn: CGRect(x: center.x - radius + 0.7, y: center.y - radius + 0.7, width: radius * 2 - 1.4, height: radius * 2 - 1.4))
                context.stroke(ridge, with: .color(.white.opacity(light)), lineWidth: 0.5)
                radius += 2.2
            }
        }
    }

    @ViewBuilder private var edge: some View {
        if let rim {
            ZStack {
                RimSpill(rim: rim)
                Circle().strokeBorder(LinearGradient(colors: [rim.top, rim.bottom], startPoint: .top, endPoint: .bottom), lineWidth: 1.6)
            }
        } else {
            Circle().strokeBorder(
                look == .unknown ? theme.unlitLegend.opacity(0.8) : .black.opacity(0.75),
                style: StrokeStyle(lineWidth: look == .unknown ? 1.2 : 0.8, dash: look == .unknown ? [2.5, 2.5] : [])
            )
        }
    }
}

/// The black backplate signals are mounted on, edged with a yellow reflective stripe.
struct SignalBackplate: View {
    private let stripe: CGFloat = 2.2
    private let cornerRadius: CGFloat = 10

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(Color(hex: 0x0B0B0B))
            Grain(seed: 11, count: 900).clipShape(shape)
            shape.strokeBorder(Signal.backplateBorder, lineWidth: stripe)
            // Reflective sheeting has a fine prismatic weave.
            Hatch(cornerRadius: cornerRadius, width: stripe)
            shape.strokeBorder(.black.opacity(0.5), lineWidth: 0.5)
            shape.inset(by: stripe).strokeBorder(.black.opacity(0.4), lineWidth: 0.5)
            GeometryReader { proxy in
                let inset: CGFloat = 6
                ForEach(0..<4, id: \.self) { index in
                    Screw(slant: .degrees(Double(index) * 53 + 35), size: 3)
                        .position(
                            x: index.isMultiple(of: 2) ? inset : proxy.size.width - inset,
                            y: index < 2 ? inset : proxy.size.height - inset
                        )
                }
            }
        }
    }
}

/// A slotted screw head.
private struct Screw: View {
    let slant: Angle
    var size: CGFloat = 2.4

    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(
                colors: [Color(hex: 0x8D8E89), Color(hex: 0x3A3B38)],
                center: UnitPoint(x: 0.35, y: 0.3),
                startRadius: 0,
                endRadius: size * 0.7
            ))
            Capsule()
                .fill(.black.opacity(0.75))
                .frame(width: size * 0.8, height: max(size * 0.18, 0.4))
                .rotationEffect(slant)
            Circle().strokeBorder(.black.opacity(0.6), lineWidth: 0.3)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.6), radius: 0.3, y: 0.3)
    }
}

/// Fine speckles of light and dark, scattered the same way every time so they never shimmer.
private struct Grain: View {
    let seed: UInt64
    let count: Int
    var tone: Color? = nil

    var body: some View {
        Canvas { context, size in
            var state = seed &* 6364136223846793005 &+ 1442695040888963407
            func next() -> CGFloat {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat(state >> 33) / CGFloat(UInt32.max >> 1)
            }
            for index in 0..<count {
                let rect = CGRect(x: next() * size.width, y: next() * size.height, width: 0.5 + next() * 0.6, height: 0.5 + next() * 0.6)
                let color = tone.map { $0.opacity(0.35) } ?? (index.isMultiple(of: 2) ? Color.white.opacity(0.05) : Color.black.opacity(0.25))
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Diagonal lines for the reflective stripe's texture, drawn only within the stripe.
private struct Hatch: View {
    let cornerRadius: CGFloat
    let width: CGFloat

    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            var band = Path(roundedRect: bounds, cornerRadius: cornerRadius, style: .continuous)
            band.addPath(Path(roundedRect: bounds.insetBy(dx: width, dy: width), cornerRadius: cornerRadius - width, style: .continuous))
            context.clip(to: band, style: FillStyle(eoFill: true))
            var x: CGFloat = -size.height
            while x < size.width {
                var line = Path()
                line.move(to: CGPoint(x: x, y: size.height))
                line.addLine(to: CGPoint(x: x + size.height, y: 0))
                context.stroke(line, with: .color(.white.opacity(0.28)), lineWidth: 0.35)
                context.stroke(line.offsetBy(dx: 0.8, dy: 0), with: .color(.black.opacity(0.18)), lineWidth: 0.35)
                x += 1.8
            }
        }
    }
}
