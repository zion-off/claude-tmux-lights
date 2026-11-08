import AppKit
import SwiftUI

/// Picks the numeral color for a lamp: the lamp's own hue, darkened until it reads against the lens.
enum LegendShade {
    static let contrast = 2.2
    static let minSaturation: CGFloat = 0.9

    static func average(_ a: UInt32, _ b: UInt32) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 { (((a >> shift) & 0xFF) + ((b >> shift) & 0xFF)) / 2 }
        return channel(16) << 16 | channel(8) << 8 | channel(0)
    }

    static func luminance(_ color: NSColor) -> Double {
        func linear(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.redComponent) + 0.7152 * linear(color.greenComponent) + 0.0722 * linear(color.blueComponent)
    }

    static func srgb(_ hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    static func contrastRatio(_ a: NSColor, _ b: NSColor) -> Double {
        let (high, low) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
        return (high + 0.05) / (low + 0.05)
    }

    static func nsColor(hue source: UInt32, against reference: UInt32) -> NSColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        srgb(source).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let background = luminance(srgb(reference))
        var level = brightness
        while level > 0 {
            let candidate = NSColor(hue: hue, saturation: max(saturation, minSaturation), brightness: level, alpha: 1)
                .usingColorSpace(.sRGB) ?? .black
            if (background + 0.05) / (luminance(candidate) + 0.05) >= contrast {
                return candidate
            }
            level -= 0.01
        }
        return .black
    }

    static func color(hue source: UInt32, against reference: UInt32) -> Color {
        Color(nsColor: nsColor(hue: source, against: reference))
    }
}
