import AppKit
import SwiftUI

enum Connection: Equatable {
    case local
    case tcp(host: String, port: UInt16)
    case ssh(host: String)

    static let sshPrefix = "ssh:"

    init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.lowercased() == "local" {
            self = .local
            return
        }
        if trimmed.hasPrefix(Self.sshPrefix) {
            let host = String(trimmed.dropFirst(Self.sshPrefix.count)).trimmingCharacters(in: .whitespaces)
            guard !host.isEmpty, !host.hasPrefix("-"), !host.contains(where: \.isWhitespace) else { return nil }
            self = .ssh(host: host)
            return
        }
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, let port = UInt16(parts[1]), port > 0 else { return nil }
        self = .tcp(host: String(parts[0]), port: port)
    }
}

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

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum Theme {
    static let legendContrast = 2.2
    static let legendMinSaturation: CGFloat = 0.9

    struct Lamp {
        let top: Color
        let bottom: Color
        let bloom: Color
        let haze: Color
        let legend: Color

        init(top: UInt32, bottom: UInt32, bloom: UInt32, haze: UInt32) {
            self.top = Color(hex: top)
            self.bottom = Color(hex: bottom)
            self.bloom = Color(hex: bloom)
            self.haze = Color(hex: haze)
            self.legend = Theme.legendShade(hue: bottom, against: Theme.average(top, bottom))
        }
    }

    static let waiting = Lamp(top: 0xFFCB45, bottom: 0xFF9F0A, bloom: 0xFFB000, haze: 0xFF7A00)
    static let busy = Lamp(top: 0x5BAEFF, bottom: 0x0A6CFF, bloom: 0x3D8BFF, haze: 0x2B55FF)

    static func average(_ a: UInt32, _ b: UInt32) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 { (((a >> shift) & 0xFF) + ((b >> shift) & 0xFF)) / 2 }
        return channel(16) << 16 | channel(8) << 8 | channel(0)
    }

    private static func luminance(_ color: NSColor) -> Double {
        func linear(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.redComponent) + 0.7152 * linear(color.greenComponent) + 0.0722 * linear(color.blueComponent)
    }

    private static func srgb(_ hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    static func legendShade(hue source: UInt32, against reference: UInt32) -> Color {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        srgb(source).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let background = luminance(srgb(reference))
        var level = brightness
        while level > 0 {
            let candidate = NSColor(hue: hue, saturation: max(saturation, legendMinSaturation), brightness: level, alpha: 1)
                .usingColorSpace(.sRGB) ?? .black
            if (background + 0.05) / (luminance(candidate) + 0.05) >= legendContrast {
                return Color(nsColor: candidate)
            }
            level -= 0.01
        }
        return .black
    }

    static let caseFill = Color(hex: 0x0F1013)
    static let unlitLens = Color(hex: 0x16181D)
    static let unlitLegend = Color(hex: 0x8A8F99)
    static let seam = Color.gray.opacity(0.5)

    static let lampSize: CGFloat = 34
    static let socketSize: CGFloat = 38
    static let spacing: CGFloat = 6
    static let seamThickness: CGFloat = 1
    static let captionGap: CGFloat = 2
    static let seamLength: CGFloat = 18
    static let padding: CGFloat = 10
    static let glowMargin: CGFloat = 14
    static let pulsePeriod = 1.8
    static let shrinkDelay = 0.3
}
