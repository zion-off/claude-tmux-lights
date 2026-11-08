import Foundation

/// Keeps one backend connection alive: frames its output into lines, and reconnects after a drop.
@MainActor
final class TrafficStream {
    enum Link { case down, up }

    private(set) var link: Link = .down
    private(set) var claudes: [Claude] = []

    private let target: Connection
    private let onChange: () -> Void
    private var transport: Transport?
    private var retry: Task<Void, Never>?
    private var buffer = Data()
    private var generation = 0
    private var stopped = false

    init(connection: Connection, onChange: @escaping () -> Void) {
        self.target = connection
        self.onChange = onChange
    }

    func start() { connect() }

    func stop() {
        stopped = true
        generation += 1
        retry?.cancel()
        retry = nil
        teardown()
    }

    private func connect() {
        guard !stopped else { return }
        generation += 1
        let gen = generation
        buffer.removeAll()

        let attempt = target.makeTransport()
        transport = attempt
        attempt.start(
            onData: { [weak self] data in
                guard let self, gen == self.generation else { return }
                self.ingest(data)
            },
            onLost: { [weak self] in self?.lost(gen) }
        )
    }

    private func teardown() {
        transport?.stop()
        transport = nil
    }

    private func ingest(_ data: Data) {
        buffer.append(data)
        var changed = false
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[buffer.startIndex..<newline])
            buffer.removeSubrange(buffer.startIndex...newline)
            guard let parsed = parseFrame(line) else { continue }
            claudes = parsed
            link = .up
            changed = true
        }
        if changed { onChange() }
    }

    private func lost(_ gen: Int) {
        guard gen == generation, !stopped else { return }
        generation += 1
        teardown()
        link = .down
        claudes = []
        onChange()
        retry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Config.retrySeconds))
            guard !Task.isCancelled else { return }
            self?.connect()
        }
    }
}
