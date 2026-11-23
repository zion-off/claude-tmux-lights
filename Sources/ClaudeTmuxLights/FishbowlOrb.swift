import AppKit
import SwiftUI

/// Sizes for a glass fishbowl: a sphere cut open at the top, half full of moving water, with a small fish.
private enum Bowl {
    static let diameter = Metrics.lampSize
    /// How far down from the top the glass is cut open, as a share of the bowl's height.
    static let openingDepth: CGFloat = 0.12
    /// How much of the sphere's underside is cut flat to make a base, as a share of its height.
    static let baseFlat: CGFloat = 0.09
    /// Where the water surface rests, as a share of the bowl's height from the top.
    static let waterLevel: CGFloat = 0.28
}

/// A sphere of glass with the top cut away and the bottom flattened so it can stand on a shelf. Closed, it
/// is the bowl's inside, to clip water to. Open, it is just the glass wall and base, so a stroke leaves the
/// top of the bowl open.
private struct BowlShape: Shape {
    let closed: Bool

    func path(in rect: CGRect) -> Path {
        let r = rect.width / 2
        let center = CGPoint(x: rect.midX, y: rect.minY + r)
        let cut = rect.height * Bowl.openingDepth
        let flat = rect.height * Bowl.baseFlat
        let lip = sqrt(r * r - (r - cut) * (r - cut))
        let foot = sqrt(r * r - (r - flat) * (r - flat))
        // Angles run clockwise from the right with y pointing down, so straight down is 90 degrees.
        let leftLip = atan2(cut - r, -lip) + 2 * .pi
        let rightLip = atan2(cut - r, lip)
        let leftFoot = atan2(r - flat, -foot)
        let rightFoot = atan2(r - flat, foot)

        func point(_ angle: Double) -> CGPoint {
            CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y + r * CGFloat(sin(angle)))
        }
        func walk(_ from: Double, _ to: Double, into path: inout Path, first: Bool) {
            let steps = 40
            for i in 0...steps {
                let angle = from + (to - from) * Double(i) / Double(steps)
                if first && i == 0 { path.move(to: point(angle)) } else { path.addLine(to: point(angle)) }
            }
        }

        // The corners where wall meets base are rounded off: the wall stops a little short of each corner,
        // and a curve bends it onto the base.
        let ease = 0.24
        let round: CGFloat = 4
        let leftCorner = point(leftFoot), rightCorner = point(rightFoot)

        var path = Path()
        // Down the left wall from the lip, around the corner, across the flat base, and up the right wall.
        walk(leftLip, leftFoot + ease, into: &path, first: true)
        path.addQuadCurve(to: CGPoint(x: leftCorner.x + round, y: leftCorner.y), control: leftCorner)
        path.addLine(to: CGPoint(x: rightCorner.x - round, y: rightCorner.y))
        path.addQuadCurve(to: point(rightFoot - ease), control: rightCorner)
        walk(rightFoot - ease, rightLip, into: &path, first: false)
        if closed { path.closeSubpath() }
        return path
    }
}

/// How agitated the water is: the tilt of its surface, and how much ripple it carries.
struct WaterState {
    var tilt = 0.0
    var agitation = 0.0
}

/// Water in a bowl that is carried along when the panel is dragged. Moving the panel gives the surface a
/// push, and a damped spring lets it rock back and forth before it settles.
final class WaterSlosh {
    static let shared = WaterSlosh()

    private var state = WaterState()
    private var velocity = 0.0
    private var lastStep: Date?
    private var lastOrigin: CGPoint?
    private var observer: NSObjectProtocol?

    /// Starts feeling the movement of `window`.
    func watch(_ window: NSWindow) {
        lastOrigin = window.frame.origin
        observer = NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self, weak window] _ in
            guard let self, let window else { return }
            let origin = window.frame.origin
            if let last = self.lastOrigin { self.push(by: origin.x - last.x) }
            self.lastOrigin = origin
        }
    }

    /// Moving right leaves the water behind, so its left side climbs.
    private func push(by dx: CGFloat) {
        let shove = Double(max(-60, min(60, dx)))
        velocity -= shove * 0.07
        state.agitation = min(1, state.agitation + abs(shove) * 0.015)
    }

    /// Lets the water settle up to `date`. Several lamps ask for the same frame, and only the first moves it.
    func advance(to date: Date) -> WaterState {
        guard let last = lastStep else {
            lastStep = date
            return state
        }
        let elapsed = min(date.timeIntervalSince(last), 0.1)
        guard elapsed > 0 else { return state }
        lastStep = date

        let omega = 2 * Double.pi / 1.1
        let damping = 0.11
        let step = 1.0 / 120
        var remaining = elapsed
        while remaining > 0 {
            let dt = min(step, remaining)
            let acceleration = -omega * omega * state.tilt - 2 * damping * omega * velocity
            velocity += acceleration * dt
            state.tilt = max(-0.55, min(0.55, state.tilt + velocity * dt))
            remaining -= dt
        }
        state.agitation *= exp(-elapsed * 1.1)
        return state
    }
}

struct FishbowlBloom: View {
    let look: Look
    let lit: LampPalette?
    let rim: LampPalette?
    let pulse: Double

    private let reach = Throb(steady: 21, base: 21, swing: 7)
    private let opacity = Throb(steady: 0.36, base: 0.24, swing: 0.36)

    var body: some View {
        if let lit {
            let waiting = look == .waiting
            let radius = CGFloat(reach.value(waiting: waiting, pulse: pulse))
            Circle()
                .fill(RadialGradient(stops: falloffStops(lit.bloom), center: .center, startRadius: Bowl.diameter * 0.42, endRadius: radius))
                .frame(width: radius * 2, height: radius * 2)
                .offset(y: 1)
                .opacity(opacity.value(waiting: waiting, pulse: pulse))
        } else if let rim {
            RimHalo(rim: rim)
        }
    }
}

struct FishbowlLens: View {
    let look: Look
    let lit: LampPalette?
    let rim: LampPalette?
    let theme: PanelTheme
    let pulse: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.pulseOverride) private var pulseOverride

    /// Makes this bowl its own: every bowl draws from the same clock, so without a seed they would all
    /// move in step. It is picked once per lamp and kept for as long as the lamp is on screen.
    @State private var seed = Double.random(in: 0..<10_000)

    /// A steady pseudo-random number between 0 and 1 for this bowl, one for each `key`.
    private func unit(_ key: Double) -> Double {
        let v = sin(seed * 12.9898 + key * 78.233) * 43758.5453
        return v - floor(v)
    }
    /// A number between `low` and `high`, steady for this bowl.
    private func varied(_ key: Double, _ low: Double, _ high: Double) -> Double {
        low + (high - low) * unit(key)
    }

    private var d: CGFloat { Bowl.diameter }
    private var level: CGFloat { d * Bowl.waterLevel }
    /// How brightly the water is lit from within.
    private var breath: Double { burn(look, pulse: pulse) }

    var body: some View {
        // The water always moves, unless motion is reduced or a frame is being held for a still.
        let still = reduceMotion || pulseOverride != nil
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: still)) { context in
            let time = still ? 0 : context.date.timeIntervalSinceReferenceDate
            let water = still ? WaterState() : WaterSlosh.shared.advance(to: context.date)
            bowl(time: time, water: water)
        }
    }

    private func bowl(time: Double, water: WaterState) -> some View {
        ZStack {
            scene(time: time, water: water)
            BowlShape(closed: true).fill(RadialGradient(
                stops: [
                    .init(color: .clear, location: 0.8),
                    .init(color: .white.opacity(0.14), location: 0.94),
                    .init(color: .white.opacity(0.3), location: 1),
                ],
                center: UnitPoint(x: 0.5, y: 0.5),
                startRadius: 0,
                endRadius: d / 2
            ))
            edge
            glints
        }
        .frame(width: d, height: d)
        .background {
            // Water bends light away from just beneath the bowl.
            Ellipse()
                .fill(.black.opacity(lit == nil ? 0.22 : 0.16))
                .frame(width: d * 0.62, height: d * 0.22)
                .blur(radius: 2)
                .offset(y: d * 0.42)
        }
    }

    // MARK: Water

    private func scene(time: Double, water: WaterState) -> some View {
        let colors: [Color] = lit.map { [$0.top, $0.bottom] } ?? [Color(hex: 0x2B3F4A), theme.unlitLens]
        let glowing = lit != nil
        let breath = breath
        let hasFish = look != .down
        let bowlRect = CGRect(x: 0, y: 0, width: d, height: d)

        return Canvas { context, size in
            var ctx = context
            ctx.clip(to: BowlShape(closed: true).path(in: bowlRect))

            // Two layers of water sliding past each other, so the surface looks like it flows.
            let back = surface(time: time, water: water, phase: 1.7, direction: -1, lift: -0.9, size: size)
            let front = surface(time: time, water: water, phase: 0, direction: 1, lift: 0, size: size)
            let gradient = GraphicsContext.Shading.linearGradient(
                Gradient(colors: colors),
                startPoint: CGPoint(x: 0, y: level - 2),
                endPoint: CGPoint(x: 0, y: size.height)
            )
            var backLayer = ctx
            backLayer.opacity = 0.55
            backLayer.fill(back.body, with: gradient)
            ctx.fill(front.body, with: gradient)

            if glowing, let lit {
                // The lamp behind the bowl swells and fades with the pulse.
                var glow = ctx
                glow.clip(to: front.body)
                glow.blendMode = .screen
                glow.fill(Path(bowlRect), with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .white.opacity(0.35 * breath), location: 0),
                        .init(color: lit.top.opacity(0.4 * breath), location: 0.35),
                        .init(color: lit.top.opacity(0), location: 1),
                    ]),
                    center: CGPoint(x: size.width / 2, y: size.height * 0.58),
                    startRadius: 0,
                    endRadius: size.width * 0.55
                ))
            }

            // The meniscus: a bright line along the top of the water.
            ctx.stroke(front.line, with: .color(.white.opacity(glowing ? 0.65 : 0.35)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round))
            var sheen = ctx
            sheen.translateBy(x: 0, y: 1.2)
            sheen.stroke(front.line, with: .color(.white.opacity(0.14)), lineWidth: 1.4)

            drawBubbles(&ctx, time: time, size: size)
            if hasFish { drawFish(&ctx, time: time, water: water, size: size, dimmed: !glowing) }
        }
        .frame(width: d, height: d)
    }

    /// One layer of water as a filled body and the line along its top. The surface tilts with the slosh, and
    /// carries a pair of slow waves that grow when the water is agitated.
    private func surface(time: Double, water: WaterState, phase: Double, direction: Double, lift: CGFloat, size: CGSize) -> (body: Path, line: Path) {
        let calm = 0.35 + 1.6 * water.agitation
        func height(_ x: CGFloat) -> CGFloat {
            let slope = CGFloat(water.tilt) * (x - size.width / 2)
            let swell = calm * sin(Double(x) * 0.34 + (time * 1.5 * varied(20, 0.8, 1.25) + 40 * unit(21)) * direction + phase)
            let chop = calm * 0.5 * sin(Double(x) * 0.72 - (time * 2.4 * varied(22, 0.8, 1.25) + 40 * unit(23)) * direction + phase * 2)
            return level + lift + slope + CGFloat(swell + chop)
        }
        var line = Path()
        var body = Path()
        let step: CGFloat = 1
        var x: CGFloat = -1
        while x <= size.width + 1 {
            let point = CGPoint(x: x, y: height(x))
            if x == -1 {
                line.move(to: point)
                body.move(to: point)
            } else {
                line.addLine(to: point)
                body.addLine(to: point)
            }
            x += step
        }
        body.addLine(to: CGPoint(x: size.width + 1, y: size.height + 1))
        body.addLine(to: CGPoint(x: -1, y: size.height + 1))
        body.closeSubpath()
        return (body, line)
    }

    // MARK: Inside the bowl

    /// A bubble now and then: one rises from the bottom, pops at the surface, and the water is calm again.
    private func drawBubbles(_ context: inout GraphicsContext, time: Double, size: CGSize) {
        let bubbles: [(Double, Double, CGFloat, CGFloat)] = [
            (varied(30, 5.5, 10), varied(31, 0, 10), CGFloat(varied(32, 0.32, 0.5)), 1.5),
            (varied(33, 8, 14), varied(34, 0, 14), CGFloat(varied(35, 0.5, 0.68)), 1.2),
        ]
        for (period, offset, x, radius) in bubbles {
            let phase = ((time + offset).truncatingRemainder(dividingBy: period)) / period
            let active = 0.28
            guard phase < active else { continue }
            let p = phase / active
            let y = size.height * 0.86 - (size.height * 0.86 - level - 1) * CGFloat(p)
            let sway = CGFloat(sin(p * 8 + offset)) * 1.1
            let center = CGPoint(x: size.width * x + sway, y: y)
            var bubble = context
            bubble.opacity = p > 0.85 ? (1 - p) / 0.15 : 1
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            bubble.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.18)))
            bubble.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.75)), lineWidth: 0.45)
            let spark = CGRect(x: rect.minX + radius * 0.35, y: rect.minY + radius * 0.3, width: radius * 0.5, height: radius * 0.5)
            bubble.fill(Path(ellipseIn: spark), with: .color(.white.opacity(0.9)))
        }
    }

    /// A small goldfish that wanders around the bowl on a lazy looping course, turning to face the way it
    /// swims, pitching up and down with its climb, and rocking a little with the slosh.
    private func drawFish(_ context: inout GraphicsContext, time: Double, water: WaterState, size: CGSize, dimmed: Bool) {
        // Two out-of-step rhythms make a path that never quite repeats.
        // Each fish has its own pace and its own place in the course.
        let fx = varied(1, 0.3, 0.55), fy = varied(2, 0.2, 0.36), fz = varied(3, 0.8, 1.1)
        let px = varied(4, 0, 6.28), py = varied(5, 0, 6.28)
        let x = size.width * (0.5 + 0.2 * sin(time * fx + px) + 0.05 * sin(time * fz))
        let y = size.height * (0.64 + 0.15 * sin(time * fy + py)) + 0.5 * sin(time * 0.8 + px)
        let vx = 0.2 * fx * cos(time * fx + px) + 0.05 * fz * cos(time * fz)
        let vy = 0.15 * fy * cos(time * fy + py)
        // The fish turns by swinging round on its length, like a real one seen side-on: its width closes
        // to a sliver as it comes about, then opens out facing the other way. A hard flip of the sign
        // would pop it across in a single frame.
        let turn = max(-1, min(1, vx / 0.045))
        let facing = CGFloat(turn >= 0 ? max(turn, 0.06) : min(turn, -0.06))
        // Pitch along the climb, kept gentle, and eased to nothing at the turns.
        let pitch = max(-0.5, min(0.5, atan2(vy, abs(vx) + 0.02) * 0.6))
        var fish = context
        fish.opacity = dimmed ? 0.62 : 1
        fish.translateBy(x: x, y: y)
        fish.scaleBy(x: facing, y: 1)
        fish.rotate(by: .radians(pitch + water.tilt * 0.4 * Double(facing)))
        drawFishBody(&fish, wag: 0.4 * sin(time * varied(6, 5.5, 7.5) + px))
    }

    /// A goldfish about eight points long, facing right, with its tail hinged on `wag`.
    private func drawFishBody(_ context: inout GraphicsContext, wag: Double) {
        let length: CGFloat = 8
        let outline = Color(hex: 0x5A1500).opacity(0.5)
        let fin = Color(hex: 0xFF5A1F).opacity(0.85)

        var tail = context
        tail.translateBy(x: -length * 0.28, y: 0)
        tail.rotate(by: .radians(wag))
        var tailPath = Path()
        tailPath.addLines([
            .zero,
            CGPoint(x: -length * 0.44, y: -length * 0.3),
            CGPoint(x: -length * 0.32, y: 0),
            CGPoint(x: -length * 0.44, y: length * 0.3),
        ])
        tailPath.closeSubpath()
        tail.fill(tailPath, with: .color(fin))

        var dorsal = Path()
        dorsal.addLines([
            CGPoint(x: length * 0.1, y: -length * 0.19),
            CGPoint(x: -length * 0.12, y: -length * 0.4),
            CGPoint(x: -length * 0.28, y: -length * 0.14),
        ])
        dorsal.closeSubpath()
        context.fill(dorsal, with: .color(fin))

        let body = Path(ellipseIn: CGRect(x: -length * 0.3, y: -length * 0.22, width: length * 0.7, height: length * 0.44))
        context.fill(body, with: .linearGradient(
            Gradient(colors: [Color(hex: 0xFF9A3C), Color(hex: 0xE8340C)]),
            startPoint: CGPoint(x: 0, y: -length * 0.22),
            endPoint: CGPoint(x: 0, y: length * 0.22)
        ))
        context.stroke(body, with: .color(outline), lineWidth: 0.35)
        context.fill(
            Path(ellipseIn: CGRect(x: -length * 0.16, y: -length * 0.18, width: length * 0.42, height: length * 0.1)),
            with: .color(.white.opacity(0.4))
        )

        let eye = CGPoint(x: length * 0.3, y: -length * 0.05)
        context.fill(Path(ellipseIn: CGRect(x: eye.x - length * 0.07, y: eye.y - length * 0.07, width: length * 0.14, height: length * 0.14)), with: .color(.white))
        context.fill(Path(ellipseIn: CGRect(x: eye.x - length * 0.035, y: eye.y - length * 0.035, width: length * 0.07, height: length * 0.07)), with: .color(.black))
    }

    // MARK: Glass

    @ViewBuilder private var edge: some View {
        if let rim {
            ZStack {
                BowlShape(closed: false)
                    .stroke(rim.bloom.opacity(0.35), lineWidth: 5)
                    .blur(radius: 2.5)
                    .clipShape(BowlShape(closed: true))
                BowlShape(closed: false)
                    .stroke(LinearGradient(colors: [rim.top, rim.bottom], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }
        } else {
            ZStack {
                BowlShape(closed: false).stroke(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.75), location: 0),
                            .init(color: .white.opacity(0.14), location: 0.5),
                            .init(color: .white.opacity(0.4), location: 1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: look == .unknown ? 1.2 : 0.9, lineCap: .round, dash: look == .unknown ? [2.5, 2.5] : [])
                )
                BowlShape(closed: false)
                    .stroke(.black.opacity(0.22), lineWidth: 0.4)
                    .padding(0.5)
            }
        }
    }

    /// A window reflected down the left wall, and a faint bounce of light on the lower right.
    private var glints: some View {
        ZStack {
            Circle()
                .trim(from: 0.5, to: 0.6)
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.8)], startPoint: .bottom, endPoint: .top),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .padding(2.4)
            Circle()
                .trim(from: 0.04, to: 0.12)
                .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                .padding(2.2)
        }
        .frame(width: d, height: d)
    }
}
