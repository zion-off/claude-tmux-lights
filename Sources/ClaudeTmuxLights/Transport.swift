import Foundation
import Network
import os

private let log = Logger(subsystem: "dev.local.ClaudeTmuxLights", category: "transport")

/// One connection attempt to a backend. It reports bytes and reports once when it is lost.
@MainActor
protocol Transport: AnyObject {
    func start(onData: @escaping @MainActor (Data) -> Void, onLost: @escaping @MainActor () -> Void)
    func stop()
}

extension Connection {
    @MainActor func makeTransport() -> Transport {
        switch self {
        case .local:
            ProcessTransport(executable: "/usr/bin/python3", arguments: ["-", "stream"], environment: Config.localEnvironment())
        case .tcp(let host, let port):
            TCPTransport(host: host, port: port)
        case .ssh(let host):
            ProcessTransport(executable: "/usr/bin/ssh", arguments: [
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=\(Config.sshConnectTimeoutSeconds)",
                "-o", "ServerAliveInterval=\(Config.sshKeepaliveSeconds)",
                "-o", "ServerAliveCountMax=3",
                "--", host, "python3", "-", "stream",
            ])
        }
    }
}

@MainActor
final class TCPTransport: Transport {
    private let host: String
    private let port: UInt16
    private var connection: NWConnection?
    private var finished = false

    init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }

    func start(onData: @escaping @MainActor (Data) -> Void, onLost: @escaping @MainActor () -> Void) {
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            log.error("invalid port \(self.port)")
            fail(onLost)
            return
        }
        let tcp = NWProtocolTCP.Options()
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 30
        tcp.keepaliveInterval = 10
        tcp.keepaliveCount = 3

        let conn = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: NWParameters(tls: nil, tcp: tcp))
        connection = conn
        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(let error):
                log.error("tcp \(self?.host ?? "?"): \(error.localizedDescription)")
                Task { @MainActor in self?.fail(onLost) }
            case .waiting:
                Task { @MainActor in self?.fail(onLost) }
            default:
                break
            }
        }
        conn.start(queue: .main)
        receive(conn, onData, onLost)
    }

    func stop() {
        finished = true
        connection?.cancel()
        connection = nil
    }

    private func receive(_ conn: NWConnection, _ onData: @escaping @MainActor (Data) -> Void, _ onLost: @escaping @MainActor () -> Void) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self, !self.finished else { return }
                if let data { onData(data) }
                if isComplete || error != nil {
                    self.fail(onLost)
                } else {
                    self.receive(conn, onData, onLost)
                }
            }
        }
    }

    private func fail(_ onLost: @MainActor () -> Void) {
        guard !finished else { return }
        finished = true
        onLost()
    }
}

/// Runs the backend script as a child process (locally, or through ssh) and reads its output.
@MainActor
final class ProcessTransport: Transport {
    private let executable: String
    private let arguments: [String]
    private let environment: [String: String]?
    private var process: Process?
    private var finished = false

    init(executable: String, arguments: [String], environment: [String: String]? = nil) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
    }

    func start(onData: @escaping @MainActor (Data) -> Void, onLost: @escaping @MainActor () -> Void) {
        guard let scriptURL = Bundle.main.url(forResource: Config.serverScriptName, withExtension: "py"),
              let script = try? Data(contentsOf: scriptURL)
        else {
            log.error("the backend script \(Config.serverScriptName).py is missing from the app bundle")
            fail(onLost)
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
                guard let self, !self.finished else { return }
                if data.isEmpty { self.fail(onLost) } else { onData(data) }
            }
        }
        child.terminationHandler = { [weak self] _ in
            Task { @MainActor in self?.fail(onLost) }
        }

        do {
            try child.run()
            process = child
            try input.fileHandleForWriting.write(contentsOf: script)
            try input.fileHandleForWriting.close()
        } catch {
            log.error("\(self.executable) failed to start: \(error.localizedDescription)")
            fail(onLost)
        }
    }

    func stop() {
        finished = true
        guard let process else { return }
        process.terminationHandler = nil
        (process.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
        if process.isRunning { process.terminate() }
        self.process = nil
    }

    private func fail(_ onLost: @MainActor () -> Void) {
        guard !finished else { return }
        finished = true
        onLost()
    }
}
