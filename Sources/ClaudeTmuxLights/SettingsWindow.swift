import AppKit
import SwiftUI

enum SettingsWindow {
    @MainActor static func make(prefs: Preferences) -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(tab("Places", symbol: "desktopcomputer", PlacesTab(prefs: prefs).frame(width: 600, height: 360)))
        tabs.addTabViewItem(tab("Panel", symbol: "slider.horizontal.3", PanelTab(prefs: prefs).frame(width: 600, height: 400)))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    @MainActor private static func tab<Content: View>(_ title: String, symbol: String, _ content: Content) -> NSTabViewItem {
        let controller = NSHostingController(rootView: content)
        controller.sizingOptions = [.preferredContentSize]
        controller.title = title
        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }
}
