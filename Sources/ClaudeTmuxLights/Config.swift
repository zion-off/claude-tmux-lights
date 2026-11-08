import Foundation

enum Config {
    static let retrySeconds = 3.0
    static let sshConnectTimeoutSeconds = 8
    static let sshKeepaliveSeconds = 10
    static let serverScriptName = "claude_traffic"
    static let localToolPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin"]

    static func localEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = (localToolPaths + [environment["PATH"] ?? "/usr/bin:/bin"]).joined(separator: ":")
        return environment
    }
}
