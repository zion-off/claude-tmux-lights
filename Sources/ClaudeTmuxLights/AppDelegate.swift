import AppKit
import Combine
import SwiftUI

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let frameName = "OrbPanel"
    private static let screenMargin: CGFloat = 16

    private let prefs: Preferences
    private let hub: StreamHub

    private lazy var panel: FloatingPanel = makePanel()
    private lazy var sizer = PanelSizer(panel: panel)
    private var settingsWindow: NSWindow?
    private var subscriptions = Set<AnyCancellable>()

    init(prefs: Preferences, hub: StreamHub) {
        self.prefs = prefs
        self.hub = hub
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildMenu()

        prefs.$alwaysOnTop
            .sink { [weak self] onTop in self?.applyLevel(onTop) }
            .store(in: &subscriptions)

        prefs.$places
            .sink { [hub] places in hub.sync(places) }
            .store(in: &subscriptions)

        panel.orderFrontRegardless()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hub.stopAll()
    }

    private func makePanel() -> FloatingPanel {
        let hosting = NSHostingView(rootView: PanelView(
            hub: hub,
            prefs: prefs,
            openSettings: { [weak self] in self?.showSettings() },
            onSize: { [weak self] size in Task { @MainActor in self?.sizer.resize(to: size) } }
        ))
        let size = hosting.fittingSize
        hosting.sizingOptions = []

        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        if !panel.setFrameUsingName(Self.frameName) { placeTopRight(panel, size) }
        panel.setFrameAutosaveName(Self.frameName)
        return panel
    }

    private func buildMenu() {
        let mainMenu = NSMenu()
        let appMenu = NSMenu()

        let configure = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        configure.target = self
        appMenu.addItem(configure)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Claude Tmux Lights", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func showSettings() {
        if settingsWindow == nil { settingsWindow = SettingsWindow.make(prefs: prefs) }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func applyLevel(_ onTop: Bool) {
        panel.level = onTop ? .floating : .normal
        if onTop { panel.orderFrontRegardless() }
    }

    private func placeTopRight(_ panel: NSPanel, _ size: CGSize) {
        guard let area = NSScreen.main?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(
            x: area.maxX - size.width - Self.screenMargin,
            y: area.maxY - size.height - Self.screenMargin
        ))
    }
}
