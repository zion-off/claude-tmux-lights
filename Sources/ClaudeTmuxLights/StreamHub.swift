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
        let states = streams.mapValues {
            StreamState(isUp: $0.stream.link == .up, claudes: $0.stream.claudes)
        }
        update(EntryBuilder.build(places: places, states: states))
    }

    private func update(_ result: [Entry]) {
        if result != entries { entries = result }
    }
}
