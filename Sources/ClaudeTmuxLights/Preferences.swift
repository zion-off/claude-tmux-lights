import Foundation

@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private enum Key: String {
        case alwaysOnTop, vertical, showBackground, showPlaceLabel, showSessionLabel, theme, attentionBurst
    }

    private let defaults: UserDefaults

    @Published var alwaysOnTop: Bool { didSet { save(alwaysOnTop, .alwaysOnTop) } }
    @Published var vertical: Bool { didSet { save(vertical, .vertical) } }
    @Published var showBackground: Bool { didSet { save(showBackground, .showBackground) } }
    @Published var showPlaceLabel: Bool { didSet { save(showPlaceLabel, .showPlaceLabel) } }
    @Published var showSessionLabel: Bool { didSet { save(showSessionLabel, .showSessionLabel) } }
    @Published var attentionBurst: Bool { didSet { save(attentionBurst, .attentionBurst) } }
    @Published var theme: String { didSet { save(theme, .theme) } }
    @Published var places: [Place] { didSet { PlacesStore.save(places, to: defaults) } }

    var style: PanelStyle {
        PanelStyle(
            vertical: vertical,
            showBackground: showBackground,
            showPlaceLabel: showPlaceLabel,
            showSessionLabel: showSessionLabel
        )
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.alwaysOnTop.rawValue: true,
            Key.vertical.rawValue: false,
            Key.showBackground.rawValue: false,
            Key.showPlaceLabel.rawValue: false,
            Key.showSessionLabel.rawValue: false,
            Key.attentionBurst.rawValue: false,
            Key.theme.rawValue: PanelTheme.default.id,
        ])
        alwaysOnTop = defaults.bool(forKey: Key.alwaysOnTop.rawValue)
        vertical = defaults.bool(forKey: Key.vertical.rawValue)
        showBackground = defaults.bool(forKey: Key.showBackground.rawValue)
        showPlaceLabel = defaults.bool(forKey: Key.showPlaceLabel.rawValue)
        showSessionLabel = defaults.bool(forKey: Key.showSessionLabel.rawValue)
        attentionBurst = defaults.bool(forKey: Key.attentionBurst.rawValue)
        theme = defaults.string(forKey: Key.theme.rawValue) ?? PanelTheme.default.id
        places = PlacesStore.load(defaults)
        PlacesStore.save(places, to: defaults)
    }

    private func save(_ value: Any, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }
}
