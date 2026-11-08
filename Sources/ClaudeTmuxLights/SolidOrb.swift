import SwiftUI

struct SolidBloom: View {
    let look: Look
    let lit: LampPalette?
    let pulse: Double

    private let diameter = Metrics.lampSize
    private let tightRadius = Throb(steady: 0.85, base: 0.9, swing: 0.2)
    private let hazeRadius = Throb(steady: 24, base: 28, swing: 12)
    private let hazeOpacity = Throb(steady: 0.4, base: 0.3, swing: 0.45)
    private let tightOpacity = Throb(steady: 0.55, base: 0.5, swing: 0.4)
    private let hazeDrop: CGFloat = 3

    var body: some View {
        if let lit {
            let waiting = look == .waiting
            let tight = diameter * tightRadius.value(waiting: waiting, pulse: pulse)
            let haze = CGFloat(hazeRadius.value(waiting: waiting, pulse: pulse))
            ZStack {
                Circle()
                    .fill(RadialGradient(stops: falloffStops(lit.haze), center: .center, startRadius: diameter * 0.4, endRadius: haze))
                    .frame(width: haze * 2, height: haze * 2)
                    .offset(y: hazeDrop)
                    .opacity(hazeOpacity.value(waiting: waiting, pulse: pulse))
                Circle()
                    .fill(RadialGradient(stops: falloffStops(lit.bloom), center: .center, startRadius: diameter * 0.35, endRadius: tight))
                    .frame(width: tight * 2, height: tight * 2)
                    .opacity(tightOpacity.value(waiting: waiting, pulse: pulse))
            }
        }
    }
}

struct SolidLens: View {
    let look: Look
    let lit: LampPalette?
    let theme: PanelTheme
    let pulse: Double

    private let diameter = Metrics.lampSize

    var body: some View {
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
}
