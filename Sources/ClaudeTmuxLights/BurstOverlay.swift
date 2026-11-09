import AppKit
import SwiftUI

/// Plays a lamp's attention burst on a transparent, click-through window the size of the display, so a
/// ripple can spread far past the small panel. Each theme draws its own effect here.
@MainActor
final class BurstOverlay {
    static let shared = BurstOverlay()

    /// The panel the lamps live in. Lamp positions are measured in its coordinates.
    weak var anchor: NSWindow?

    /// How far the ripple reaches, as a share of the display's width.
    private static let reach: CGFloat = 0.25

    /// `point` is the lamp's center in the anchor window's coordinates, measured from its top left.
    private var lastFinish = Date.distantPast

    func fire(from point: CGPoint, theme: PanelTheme, kind: BurstKind) {
        guard let anchor else { return }
        // Several Claudes finishing together play one ripple, not a pile of them.
        if kind == .finished {
            guard Date().timeIntervalSince(lastFinish) > 1 else { return }
            lastFinish = Date()
        }
        let screen = anchor.screen ?? NSScreen.main
        guard let screen else { return }

        let origin = CGPoint(
            x: anchor.frame.minX + point.x - screen.frame.minX,
            y: screen.frame.maxY - (anchor.frame.maxY - point.y)
        )
        let window = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.level = NSWindow.Level(rawValue: anchor.level.rawValue + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: BurstScene(
            theme: theme,
            origin: origin,
            maxRadius: screen.frame.width * Self.reach * (kind == .finished ? 0.5 : 1),
            kind: kind,
            start: Date()
        ))
        window.orderFrontRegardless()

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(kind.duration + 0.2))
            window.close()
        }
    }
}

private struct BurstScene: View {
    let theme: PanelTheme
    let origin: CGPoint
    let maxRadius: CGFloat
    let kind: BurstKind
    let start: Date

    var body: some View {
        TimelineView(.animation) { context in
            let color = kind == .finished ? theme.busy.bloom : theme.waiting.bloom
            let gentle = kind == .finished
            let progress = context.date.timeIntervalSince(start) / kind.duration
            ZStack {
                switch theme.finish {
                case .frosted: FrostedRipple(color: color, progress: progress, maxRadius: maxRadius, gentle: gentle)
                case .solid: SolidBurst(color: color, progress: progress, maxRadius: maxRadius, gentle: gentle)
                case .glass: GlassBurst(color: color, progress: progress, maxRadius: maxRadius, gentle: gentle)
                case .jewel: JewelBurst(color: color, progress: progress, maxRadius: maxRadius, gentle: gentle)
                case .signal: SignalBurst(color: color, progress: progress, maxRadius: maxRadius, gentle: gentle)
                }
            }
            .opacity(gentle ? 0.75 : 1)
            .position(origin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}
