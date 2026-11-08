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

    private var panel: FloatingPanel!
    private var settingsWindow: NSWindow?
    private var subscriptions = Set<AnyCancellable>()
    private var pendingShrink: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildMenu()

        let hosting = NSHostingView(rootView: PanelView(
            hub: .shared,
            prefs: .shared,
            openSettings: { [weak self] in self?.showSettings() },
            onSize: { [weak self] size in Task { @MainActor in self?.resize(to: size) } }
        ))
        let size = hosting.fittingSize
        hosting.sizingOptions = []

        panel = FloatingPanel(
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

        if !panel.setFrameUsingName(Self.frameName) { placeTopRight(size) }
        panel.setFrameAutosaveName(Self.frameName)

        Preferences.shared.$alwaysOnTop
            .sink { [weak self] onTop in self?.applyLevel(onTop) }
            .store(in: &subscriptions)

        Preferences.shared.$places
            .sink { places in StreamHub.shared.sync(places) }
            .store(in: &subscriptions)

        panel.orderFrontRegardless()
    }

    func applicationWillTerminate(_ notification: Notification) {
        StreamHub.shared.stopAll()
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
        if settingsWindow == nil { settingsWindow = makeSettingsWindow() }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func makeSettingsWindow() -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(settingsTab("Places", symbol: "desktopcomputer", PlacesTab(prefs: .shared).frame(width: 600, height: 360)))
        tabs.addTabViewItem(settingsTab("Panel", symbol: "slider.horizontal.3", PanelTab(prefs: .shared).frame(width: 600, height: 400)))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func settingsTab<Content: View>(_ title: String, symbol: String, _ content: Content) -> NSTabViewItem {
        let controller = NSHostingController(rootView: content)
        controller.sizingOptions = [.preferredContentSize]
        controller.title = title
        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }

    private func applyLevel(_ onTop: Bool) {
        panel.level = onTop ? .floating : .normal
        if onTop { panel.orderFrontRegardless() }
    }

    private func resize(to size: CGSize) {
        pendingShrink?.cancel()
        pendingShrink = nil
        let current = panel.frame.size
        guard size.width > 0, size != current else { return }

        guard size.width < current.width || size.height < current.height else {
            apply(size)
            return
        }
        apply(CGSize(width: max(size.width, current.width), height: max(size.height, current.height)))
        let shrink = DispatchWorkItem { [weak self] in self?.apply(size) }
        pendingShrink = shrink
        DispatchQueue.main.asyncAfter(deadline: .now() + Theme.shrinkDelay, execute: shrink)
    }

    private func apply(_ size: CGSize) {
        guard panel.frame.size != size else { return }
        var frame = panel.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        panel.setFrame(frame, display: true)
    }

    private func placeTopRight(_ size: CGSize) {
        guard let area = NSScreen.main?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(
            x: area.maxX - size.width - Self.screenMargin,
            y: area.maxY - size.height - Self.screenMargin
        ))
    }
}
