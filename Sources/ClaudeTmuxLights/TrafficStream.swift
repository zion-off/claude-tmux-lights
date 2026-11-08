import Foundation
import Network

@MainActor
final class TrafficStream {
    enum Link { case down, up }

    private(set) var link: Link = .down
    private(set) var claudes: [Claude] = []

    private let target: Connection
    private let onChange: () -> Void
    private var connection: NWConnection?
    private var process: Process?
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
        teardown()
    }

    private func connect() {
        guard !stopped else { return }
        generation += 1
        let gen = generation
        buffer.removeAll()

        switch target {
        case .local: connectLocal(gen)
        case .tcp(let host, let port): connectTCP(host: host, port: port, gen)
        case .ssh(let host): connectSSH(host: host, gen)
        }
    }

    private func teardown() {
        connection?.cancel()
        connection = nil
        if let process {
            process.terminationHandler = nil
            (process.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
            if process.isRunning { process.terminate() }
        }
        process = nil
    }

    private func connectTCP(host: String, port: UInt16, _ gen: Int) {
        let tcp = NWProtocolTCP.Options()
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 30
        tcp.keepaliveInterval = 10
        tcp.keepaliveCount = 3

        let conn = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: NWParameters(tls: nil, tcp: tcp)
        )
        connection = conn
        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .waiting:
                Task { @MainActor in self?.lost(gen) }
            default:
                break
            }
        }
        conn.start(queue: .main)
        receive(conn, gen)
    }

    private func receive(_ conn: NWConnection, _ gen: Int) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self, gen == self.generation else { return }
                if let data { self.ingest(data) }
                if isComplete || error != nil {
                    self.lost(gen)
                } else {
                    self.receive(conn, gen)
                }
            }
        }
    }

    private func connectSSH(host: String, _ gen: Int) {
        spawn("/usr/bin/ssh", [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=\(Config.sshConnectTimeoutSeconds)",
            "-o", "ServerAliveInterval=\(Config.sshKeepaliveSeconds)",
            "-o", "ServerAliveCountMax=3",
            "--", host, "python3", "-", "stream",
        ], gen)
    }

    private func connectLocal(_ gen: Int) {
        spawn("/usr/bin/python3", ["-", "stream"], environment: Config.localEnvironment(), gen)
    }

    private func spawn(_ executable: String, _ arguments: [String], environment: [String: String]? = nil, _ gen: Int) {
        guard let scriptURL = Bundle.main.url(forResource: Config.serverScriptName, withExtension: "py"),
              let script = try? Data(contentsOf: scriptURL)
        else {
            lost(gen)
            return
        }

        let child = Process()
        child.executableURL = URL(fileURLWithPath: executable)
        child.arguments = arguments
        if let environment { child.environment = environment }
        let input = Pipe()
        let output = Pipe()
        child.standardInput = input
        child.standardOutput = output
        child.standardError = FileHandle.nullDevice

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil }
            Task { @MainActor in
                guard let self, gen == self.generation else { return }
                if data.isEmpty { self.lost(gen) } else { self.ingest(data) }
            }
        }
        child.terminationHandler = { [weak self] _ in
            Task { @MainActor in self?.lost(gen) }
        }

        do {
            try child.run()
            process = child
            try input.fileHandleForWriting.write(contentsOf: script)
            try input.fileHandleForWriting.close()
        } catch {
            lost(gen)
        }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + Config.retrySeconds) { [weak self] in
            Task { @MainActor in self?.connect() }
        }
    }
}
