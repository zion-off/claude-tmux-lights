import Foundation

@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    @Published var alwaysOnTop: Bool {
        didSet { defaults.set(alwaysOnTop, forKey: "alwaysOnTop") }
    }
    @Published var vertical: Bool {
        didSet { defaults.set(vertical, forKey: "vertical") }
    }
    @Published var showBackground: Bool {
        didSet { defaults.set(showBackground, forKey: "showBackground") }
    }
    @Published var showPlaceLabel: Bool {
        didSet { defaults.set(showPlaceLabel, forKey: "showPlaceLabel") }
    }
    @Published var showSessionLabel: Bool {
        didSet { defaults.set(showSessionLabel, forKey: "showSessionLabel") }
    }
    @Published var places: [Place] {
        didSet { Self.save(places, to: defaults) }
    }

    private init() {
        defaults.register(defaults: [
            "alwaysOnTop": true,
            "vertical": false,
            "showBackground": false,
            "showPlaceLabel": false,
            "showSessionLabel": false,
        ])
        alwaysOnTop = defaults.bool(forKey: "alwaysOnTop")
        vertical = defaults.bool(forKey: "vertical")
        showBackground = defaults.bool(forKey: "showBackground")
        showPlaceLabel = defaults.bool(forKey: "showPlaceLabel")
        showSessionLabel = defaults.bool(forKey: "showSessionLabel")
        places = Self.loadPlaces(defaults)
        Self.save(places, to: defaults)
    }

    private static func loadPlaces(_ defaults: UserDefaults) -> [Place] {
        if let data = defaults.data(forKey: "places"), let saved = try? JSONDecoder().decode([Place].self, from: data) {
            return saved
        }
        guard let old = defaults.string(forKey: "connection"), let connection = Connection(old) else {
            return [Place.thisMac()]
        }
        switch connection {
        case .local: return [Place.thisMac()]
        case .ssh(let host): return [Place(name: host, kind: .ssh, address: host)]
        case .tcp(let host, let port): return [Place(name: "\(host):\(port)", kind: .tcp, address: "\(host):\(port)")]
        }
    }

    private static func save(_ places: [Place], to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(places) { defaults.set(data, forKey: "places") }
    }
}
