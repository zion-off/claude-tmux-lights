import Foundation

enum Status: String {
    case busy, waiting, idle, unknown
}

struct Claude: Decodable, Identifiable, Equatable {
    var id: String
    let group: String
    let label: String
    let status: String
    let sortKey: Int
    var placeID = ""
    var placeName = ""

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
        self.status = try c.decode(String.self, forKey: .status)
        self.sortKey = window ?? Int(label) ?? Int.max
    }

    var kind: Status { Status(rawValue: status) ?? .unknown }
    var tooltip: String { "\(group):\(label) \(status)" + (placeName.isEmpty ? "" : " (\(placeName))") }
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

enum Entry: Identifiable, Equatable {
    case claude(Claude)
    case offline(placeID: String, placeName: String, tooltip: String)

    var id: String {
        switch self {
        case .claude(let claude): claude.id
        case .offline(let placeID, _, _): "offline-\(placeID)"
        }
    }

    var groupKey: String {
        switch self {
        case .claude(let claude): "\(claude.placeID)|\(claude.group)"
        case .offline(let placeID, _, _): placeID
        }
    }
}
