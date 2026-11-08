import Foundation

@MainActor
final class StreamHub: ObservableObject {
    static let shared = StreamHub()

    @Published private(set) var entries: [Entry] = []

    private var streams: [String: (stream: TrafficStream, connection: Connection)] = [:]
    private var places: [Place] = []

    func sync(_ newPlaces: [Place]) {
        places = newPlaces
        let enabled = newPlaces.filter(\.enabled)
        let wanted = Set(enabled.map(\.id))

        for id in streams.keys where !wanted.contains(id) {
            streams[id]?.stream.stop()
            streams[id] = nil
        }
        for place in enabled {
            guard let connection = place.connection else {
                streams[place.id]?.stream.stop()
                streams[place.id] = nil
                continue
            }
            if let existing = streams[place.id], existing.connection == connection { continue }
            streams[place.id]?.stream.stop()
            let stream = TrafficStream(connection: connection) { [weak self] in self?.rebuild() }
            streams[place.id] = (stream, connection)
            stream.start()
        }
        rebuild()
    }

    func stopAll() {
        for entry in streams.values { entry.stream.stop() }
        streams.removeAll()
    }

    private func rebuild() {
        let enabled = places.filter(\.enabled)
        guard !enabled.isEmpty else {
            update([.offline(placeID: "none", placeName: "", tooltip: "No place is turned on. Right-click, then choose Settings…")])
            return
        }

        var result: [Entry] = []
        for place in enabled {
            guard let stream = streams[place.id]?.stream else {
                result.append(.offline(placeID: place.id, placeName: place.name, tooltip: "\(place.name): check the address in Settings…"))
                continue
            }
            if stream.link == .down {
                result.append(.offline(placeID: place.id, placeName: place.name, tooltip: "\(place.name): not connected"))
                continue
            }
            for claude in stream.claudes {
                var shown = claude
                shown.placeID = place.id
                shown.placeName = place.name
                shown.id = "\(place.id)|\(claude.id)"
                result.append(.claude(shown))
            }
        }
        update(result)
    }

    private func update(_ result: [Entry]) {
        if result != entries { entries = result }
    }
}
