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
