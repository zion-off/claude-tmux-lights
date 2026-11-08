import AppKit

/// Resizes the panel to fit its content. It grows at once and shrinks after a short delay, so a
/// lamp that disappears and comes back doesn't make the panel jump.
@MainActor
final class PanelSizer {
    private static let shrinkDelay = 0.3

    private let panel: NSPanel
    private var pendingShrink: Task<Void, Never>?

    init(panel: NSPanel) {
        self.panel = panel
    }

    func resize(to size: CGSize) {
        pendingShrink?.cancel()
        pendingShrink = nil
        let current = panel.frame.size
        guard size.width > 0, size != current else { return }

        guard size.width < current.width || size.height < current.height else {
            apply(size)
            return
        }
        apply(CGSize(width: max(size.width, current.width), height: max(size.height, current.height)))
        pendingShrink = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.shrinkDelay))
            guard !Task.isCancelled else { return }
            self?.apply(size)
        }
    }

    private func apply(_ size: CGSize) {
        guard panel.frame.size != size else { return }
        var frame = panel.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        panel.setFrame(frame, display: true)
    }
}
