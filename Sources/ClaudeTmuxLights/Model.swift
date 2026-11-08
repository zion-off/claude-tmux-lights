import Foundation

enum Status: String {
    case busy, waiting, idle, unknown
}

struct Claude: Decodable, Identifiable, Equatable {
    let id: String
    let group: String
    let label: String
    let status: Status
    let sortKey: Int

    private enum Keys: String, CodingKey {
        case id, group, label, status, session, window
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let session = try c.decodeIfPresent(String.self, forKey: .session)
        let window = try c.decodeIfPresent(Int.self, forKey: .window)

        guard let label = try c.decodeIfPresent(String.self, forKey: .label) ?? window.map(String.init) else {
            throw DecodingError.dataCorruptedError(forKey: .label, in: c, debugDescription: "no label")
        }
        guard let id = try c.decodeIfPresent(String.self, forKey: .id)
            ?? session.flatMap({ s in window.map { "\(s):\($0)" } })
        else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "no id")
        }

        self.id = id
        self.label = label
        self.group = try c.decodeIfPresent(String.self, forKey: .group) ?? session ?? ""
        self.status = Status(rawValue: try c.decode(String.self, forKey: .status)) ?? .unknown
        self.sortKey = window ?? Int(label) ?? Int.max
    }

}

struct PlacedClaude: Identifiable, Equatable {
    let claude: Claude
    let placeID: String
    let placeName: String

    var id: EntryID { .claude(placeID: placeID, id: claude.id) }
    var tooltip: String {
        "\(claude.group):\(claude.label) \(claude.status.rawValue)" + (placeName.isEmpty ? "" : " (\(placeName))")
    }
}

private struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

private struct Frame: Decodable {
    let claudes: [Lossy<Claude>]
}

func parseFrame(_ line: Data) -> [Claude]? {
    guard let frame = try? JSONDecoder().decode(Frame.self, from: line) else { return nil }
    return frame.claudes.compactMap(\.value).sorted {
        ($0.group, $0.sortKey, $0.id) < ($1.group, $1.sortKey, $1.id)
    }
}

enum EntryID: Hashable {
    case claude(placeID: String, id: String)
    case offline(placeID: String)
}

struct GroupKey: Hashable {
    let placeID: String
    let session: String?
}

enum OfflineReason: Equatable {
    case noPlaceEnabled
    case badAddress
    case disconnected

    func tooltip(place: String) -> String {
        switch self {
        case .noPlaceEnabled: "No place is turned on. Right-click, then choose Settings…"
        case .badAddress: "\(place): check the address in Settings…"
        case .disconnected: "\(place): not connected"
        }
    }
}

enum Entry: Identifiable, Equatable {
    static let noPlaceID = "none"

    case claude(PlacedClaude)
    case offline(placeID: String, placeName: String, reason: OfflineReason)

    var id: EntryID {
        switch self {
        case .claude(let placed): placed.id
        case .offline(let placeID, _, _): .offline(placeID: placeID)
        }
    }

    var groupKey: GroupKey {
        switch self {
        case .claude(let placed): GroupKey(placeID: placed.placeID, session: placed.claude.group)
        case .offline(let placeID, _, _): GroupKey(placeID: placeID, session: nil)
        }
    }

    var placeName: String {
        switch self {
        case .claude(let placed): placed.placeName
        case .offline(_, let placeName, _): placeName
        }
    }

    var tooltip: String {
        switch self {
        case .claude(let placed): placed.tooltip
        case .offline(_, let placeName, let reason): reason.tooltip(place: placeName)
        }
    }
}
