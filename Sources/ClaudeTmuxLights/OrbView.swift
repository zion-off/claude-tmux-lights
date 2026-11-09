import SwiftUI

enum Look {
    case waiting, busy, shell, idle, unknown, down

    init(_ status: Status) {
        switch status {
        case .waiting: self = .waiting
        case .busy: self = .busy
        case .shell: self = .shell
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

/// Whether a lamp flashes once when it starts waiting. Set from the preference.
private struct AttentionBurstKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var attentionBurst: Bool {
        get { self[AttentionBurstKey.self] }
        set { self[AttentionBurstKey.self] = newValue }
    }
}

/// Whether a lamp also flashes, more gently, when its Claude finishes. Set from the preferences.
private struct FinishBurstKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var finishBurst: Bool {
        get { self[FinishBurstKey.self] }
        set { self[FinishBurstKey.self] = newValue }
    }
}

/// How long a Claude must have worked for its finish to be worth a flash. Set from the preferences.
private struct FinishMinimumKey: EnvironmentKey {
    static let defaultValue: TimeInterval = 10
}

extension EnvironmentValues {
    var finishMinimum: TimeInterval {
        get { self[FinishMinimumKey.self] }
        set { self[FinishMinimumKey.self] = newValue }
    }
}

/// The two moments a burst can mark.
enum BurstKind {
    /// A Claude needs you.
    case waiting
    /// A Claude has finished and is ready for your next prompt.
    case finished

    var duration: Double { self == .waiting ? 2.4 : 3.0 }
}

enum Burst {
    static let duration = BurstKind.waiting.duration

    /// How far through the burst a lamp is, from 0 to 1, or nil when none is playing.
    static func progress(since start: Date?, at now: Date) -> Double? {
        guard let start else { return nil }
        let t = now.timeIntervalSince(start) / duration
        return (0..<1).contains(t) ? t : nil
    }

    /// A flash that peaks at the start and is gone by `span` of the way through.
    static func flash(_ progress: Double?, span: Double = 0.45) -> Double {
        guard let progress else { return 0 }
        return max(0, 1 - progress / span)
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

/// How hard a lamp lit from within is burning: it swells and fades while waiting, and holds steady
/// otherwise. It never drops below a third, so the lamp still reads as lit at the bottom of the pulse.
func burn(_ look: Look, pulse: Double) -> Double {
    look == .waiting ? 0.35 + 0.65 * pulse : 0.8
}

func falloffStops(_ color: Color) -> [Gradient.Stop] {
    [(0.0, 0.95), (0.2, 0.6), (0.4, 0.3), (0.6, 0.13), (0.8, 0.04), (1.0, 0.0)]
        .map { Gradient.Stop(color: color.opacity($0.1), location: $0.0) }
}

/// The faint halo hugging a lit rim, shared by every finish.
struct RimHalo: View {
    let rim: LampPalette

    private let diameter = Metrics.lampSize
    private let reach: CGFloat = 8

    var body: some View {
        let radius = diameter / 2 + reach
        Circle()
            .fill(RadialGradient(stops: falloffStops(rim.bloom), center: .center, startRadius: diameter / 2, endRadius: radius))
            .frame(width: radius * 2, height: radius * 2)
            .opacity(0.35)
    }
}

/// A rim's light bleeding a little way into the dark lens.
struct RimSpill: View {
    let rim: LampPalette

    var body: some View {
        Circle()
            .strokeBorder(rim.bloom.opacity(0.35), lineWidth: 5)
            .blur(radius: 2.5)
            .clipShape(Circle())
    }
}

struct OrbView: View {
    let look: Look
    let label: String
    let tooltip: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.pulseOverride) private var pulseOverride
    @Environment(\.panelTheme) private var theme
    @Environment(\.attentionBurst) private var burstEnabled
    @Environment(\.finishBurst) private var finishEnabled
    @Environment(\.finishMinimum) private var finishMinimum

    @State private var burstStart: Date?
    @State private var center = CGPoint.zero
    @State private var busySince: Date?

    private var lit: LampPalette? { theme.lamp(for: look) }
    private var rim: LampPalette? { theme.rim(for: look) }
    /// The palette the numeral sits on, if its lens is lit at all.
    private var glow: LampPalette? { lit ?? (theme.finish.shellLightsLens ? rim : nil) }
    private var legendColor: Color { glow?.legend ?? rim?.top ?? theme.unlitLegend }

    private static let restingPulse = 0.8

    var body: some View {
        let animates = look == .waiting && !reduceMotion && pulseOverride == nil
        TimelineView(.animation(paused: !animates)) { context in
            let phase = 0.5 + 0.5 * sin(context.date.timeIntervalSinceReferenceDate * 2 * .pi / Motion.pulsePeriod)
            let wave = phase * phase * (3 - 2 * phase)
            let burst = animates ? Burst.progress(since: burstStart, at: context.date) : nil
            lamp(pulse: pulseOverride ?? (animates ? wave : Self.restingPulse), burst: burst)
        }
        .onAppear { if look == .busy { busySince = Date() } }
        .onChange(of: look) { old, new in
            // Answering a question puts you in the Claude already, so that run's finish isn't flashed.
            if new == .busy, old != .busy { busySince = old == .waiting ? nil : Date() }
            if finishEnabled, !reduceMotion, old == .busy, new == .idle,
               let busySince, Date().timeIntervalSince(busySince) >= finishMinimum {
                BurstOverlay.shared.fire(from: center, theme: theme, kind: .finished)
            }
            if burstEnabled, !reduceMotion, new == .waiting, old != .waiting {
                burstStart = Date()
                BurstOverlay.shared.fire(from: center, theme: theme, kind: .waiting)
            }
        }
        .onGeometryChange(for: CGPoint.self) { proxy in
            let frame = proxy.frame(in: .global)
            return CGPoint(x: frame.midX, y: frame.midY)
        } action: { center = $0
        }
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }

    /// The pulse the lamp is drawn with, lifted by the burst in the style of the theme: Frosted does its own
    /// flash, Traffic Light strobes, and the rest swell to full brightness and fall back.
    private func burstPulse(_ pulse: Double, _ burst: Double?) -> Double {
        guard let burst else { return pulse }
        switch theme.finish {
        case .frosted: return pulse
        case .signal: return Int(burst / 0.06).isMultiple(of: 2) && burst < 0.5 ? 1 : pulse * 0.4
        case .jewel: return max(pulse, Burst.flash(burst, span: 0.3))
        case .solid, .glass: return max(pulse, Burst.flash(burst))
        }
    }

    /// A little pop as the burst starts, for the finishes that suit it.
    private func burstScale(_ burst: Double?) -> CGFloat {
        switch theme.finish {
        case .solid: 1 + 0.16 * Burst.flash(burst, span: 0.3)
        case .glass: 1 + 0.1 * Burst.flash(burst, span: 0.4)
        case .jewel, .signal, .frosted: 1
        }
    }

    private func lamp(pulse rawPulse: Double, burst: Double?) -> some View {
        let pulse = burstPulse(rawPulse, burst)
        return ZStack {
            lens(pulse: pulse, burst: burst)
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(legendColor)
                .shadow(color: glow == nil ? .clear : legendColor.opacity(0.35), radius: 0.4, y: -0.5)
                .shadow(color: glow == nil ? .clear : .white.opacity(0.32), radius: 0.8, y: 0.9)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(width: Metrics.lampSize - 6)
        }
        .scaleEffect(burstScale(burst))
        .frame(width: Metrics.socketSize, height: Metrics.socketSize)
        .background { bloom(pulse: pulse, burst: burst) }
    }

    @ViewBuilder private func lens(pulse: Double, burst: Double?) -> some View {
        switch theme.finish {
        case .solid: SolidLens(look: look, lit: lit, rim: rim, theme: theme, pulse: pulse)
        case .glass: GlassBead(look: look, lit: lit, rim: rim, theme: theme, pulse: pulse)
        case .jewel: JewelLens(look: look, lit: lit, rim: rim, theme: theme, pulse: pulse)
        case .signal: SignalLens(look: look, lit: lit, rim: rim, theme: theme, pulse: pulse)
        case .frosted: FrostedButton(look: look, lit: lit, rim: rim, theme: theme, pulse: pulse, burst: burst)
        }
    }

    @ViewBuilder private func bloom(pulse: Double, burst: Double?) -> some View {
        switch theme.finish {
        case .solid: SolidBloom(look: look, lit: lit, rim: rim, pulse: pulse)
        case .glass: GlassBloom(look: look, lit: lit, rim: rim, pulse: pulse)
        case .jewel: JewelBloom(look: look, lit: lit, rim: rim, pulse: pulse)
        case .signal: SignalBloom(look: look, lit: lit, rim: rim, pulse: pulse)
        case .frosted: FrostedBloom(look: look, lit: lit, rim: rim, pulse: pulse, burst: burst)
        }
    }
}
