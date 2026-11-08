import Foundation

enum PlaceKind: String, Codable, CaseIterable, Identifiable {
    case local, ssh, tcp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local: "This Mac"
        case .ssh: "Another computer (SSH)"
        case .tcp: "A running service"
        }
    }

    var hint: String {
        switch self {
        case .local: "Claude sessions in tmux on this Mac. There's nothing to set up."
        case .ssh: "Logs in with your SSH keys, so it has to work without a password. The other computer needs python3 and tmux."
        case .tcp: "For a backend you already run, such as claude_traffic.py serve."
        }
    }
}

struct Place: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var name: String
    var kind: PlaceKind
    var address = ""
    var enabled = true

    var connection: Connection? {
        switch kind {
        case .local: .local
        case .ssh: Connection(Connection.sshPrefix + address)
        case .tcp: Connection(address)
        }
    }

    static func thisMac() -> Place { Place(name: "This Mac", kind: .local) }

    init(name: String, kind: PlaceKind, address: String = "", enabled: Bool = true) {
        self.name = name
        self.kind = kind
        self.address = address
        self.enabled = enabled
    }
}

enum Connection: Equatable {
    case local
    case tcp(host: String, port: UInt16)
    case ssh(host: String)

    static let sshPrefix = "ssh:"

    init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.lowercased() == "local" {
            self = .local
            return
        }
        if trimmed.hasPrefix(Self.sshPrefix) {
            let host = String(trimmed.dropFirst(Self.sshPrefix.count)).trimmingCharacters(in: .whitespaces)
            guard !host.isEmpty, !host.hasPrefix("-"), !host.contains(where: \.isWhitespace) else { return nil }
            self = .ssh(host: host)
            return
        }
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, let port = UInt16(parts[1]), port > 0 else { return nil }
        self = .tcp(host: String(parts[0]), port: port)
    }
}

enum PlacesStore {
    private static let key = "places"
    private static let legacyKey = "connection"

    static func load(_ defaults: UserDefaults) -> [Place] {
        if let data = defaults.data(forKey: key), let saved = try? JSONDecoder().decode([Place].self, from: data) {
            return saved
        }
        guard let old = defaults.string(forKey: legacyKey), let connection = Connection(old) else {
            return [Place.thisMac()]
        }
        switch connection {
        case .local: return [Place.thisMac()]
        case .ssh(let host): return [Place(name: host, kind: .ssh, address: host)]
        case .tcp(let host, let port): return [Place(name: "\(host):\(port)", kind: .tcp, address: "\(host):\(port)")]
        }
    }

    static func save(_ places: [Place], to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(places) { defaults.set(data, forKey: key) }
    }
}
