import AppKit
import Combine
import SwiftUI

/// Sections shown in the settings sidebar. To add one: add a case, give it a title, symbol and
/// color, and return its view from `SettingsDetail`.
enum SettingsSection: String, CaseIterable, Identifiable {
    case general, appearance, alerts, places

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .alerts: "Alerts"
        case .places: "Places"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .appearance: "paintpalette.fill"
        case .alerts: "bell.badge.fill"
        case .places: "network"
        }
    }

    var color: Color {
        switch self {
        case .general: .gray
        case .appearance: .blue
        case .alerts: .red
        case .places: .green
        }
    }
}

@MainActor
final class SettingsSelection: ObservableObject {
    @Published var section: SettingsSection = .general
}

/// System Settings–style window: an AppKit sidebar split view with a toolbar whose
/// sidebar-tracking separator puts the section title at the start of the content column.
@MainActor
final class SettingsWindowController: NSWindowController, NSToolbarDelegate {
    private let selection: SettingsSelection
    private var titleSubscription: AnyCancellable?

    init(prefs: Preferences) {
        let selection = SettingsSelection()
        self.selection = selection

        let sidebar = NSHostingController(rootView: SettingsSidebar(selection: selection))
        let detail = NSHostingController(rootView: SettingsDetail(selection: selection, prefs: prefs))
        sidebar.sizingOptions = []
        detail.sizingOptions = []

        let split = NSSplitViewController()
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarItem.canCollapse = false
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 200
        split.addSplitViewItem(sidebarItem)
        split.addSplitViewItem(NSSplitViewItem(viewController: detail))

        let window = NSWindow(contentViewController: split)
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 720, height: 500))
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified

        titleSubscription = selection.$section.sink { [weak window] section in
            window?.title = section.title
        }
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.sidebarTrackingSeparator]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.sidebarTrackingSeparator]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        nil // only system items
    }
}
