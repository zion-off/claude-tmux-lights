import Foundation

struct StreamState {
    let isUp: Bool
    let claudes: [Claude]
}

enum EntryBuilder {
    static func build(places: [Place], states: [String: StreamState]) -> [Entry] {
        let enabled = places.filter(\.enabled)
        guard !enabled.isEmpty else {
            return [.offline(placeID: Entry.noPlaceID, placeName: "", reason: .noPlaceEnabled)]
        }

        var result: [Entry] = []
        for place in enabled {
            guard let state = states[place.id] else {
                result.append(.offline(placeID: place.id, placeName: place.name, reason: .badAddress))
                continue
            }
            guard state.isUp else {
                result.append(.offline(placeID: place.id, placeName: place.name, reason: .disconnected))
                continue
            }
            for claude in state.claudes {
                result.append(.claude(PlacedClaude(claude: claude, placeID: place.id, placeName: place.name)))
            }
        }
        return result
    }
}
