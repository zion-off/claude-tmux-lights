import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

let canvas = CGSize(width: 830, height: 240)
let renderScale: CGFloat = 1.25
let framesPerSecond = 15.0
let panelScale: CGFloat = 1.9

let mac = ("mac", "This Mac")
let vm = ("vm", "VM")

func lamp(_ label: String, _ status: String, _ session: String, _ place: (String, String)) -> Entry {
    let json = #"{"claudes":[{"id":"@\#(label)\#(session)","group":"\#(session)","label":"\#(label)","status":"\#(status)"}]}"#
    let claude = parseFrame(Data(json.utf8))!.first!
    return .claude(PlacedClaude(claude: claude, placeID: place.0, placeName: place.1))
}

struct Moment {
    let seconds: Double
    let entries: [Entry]
    let glass: Bool
    let labels: Bool
}

let moments: [Moment] = [
    Moment(seconds: 1.6, entries: [lamp("1", "idle", "work", mac), lamp("2", "busy", "work", mac), lamp("3", "busy", "work", mac)], glass: false, labels: false),
    Moment(seconds: 2.2, entries: [lamp("1", "idle", "work", mac), lamp("2", "waiting", "work", mac), lamp("3", "busy", "work", mac)], glass: false, labels: false),
    Moment(seconds: 2.8, entries: [lamp("1", "idle", "work", mac), lamp("2", "waiting", "work", mac), lamp("3", "busy", "work", mac), lamp("1", "busy", "deploy", mac), lamp("3", "idle", "work", vm)], glass: true, labels: true),
    Moment(seconds: 1.8, entries: [lamp("1", "idle", "work", mac), lamp("2", "busy", "work", mac), lamp("3", "busy", "work", mac), lamp("1", "busy", "deploy", mac), lamp("3", "waiting", "work", vm)], glass: true, labels: true),
]

struct Scene: View {
    let moment: Moment
    let time: Double

    var body: some View {
        let phase = 0.5 + 0.5 * sin(time * 2 * .pi / Motion.pulsePeriod)
        let pulse = phase * phase * (3 - 2 * phase)
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1E2026), Color(hex: 0x121317)], startPoint: .top, endPoint: .bottom)
            LightBar(
                entries: moment.entries,
                style: PanelStyle(showBackground: moment.glass, showPlaceLabel: moment.labels, showSessionLabel: moment.labels)
            )
            .environment(\.pulseOverride, pulse)
            .scaleEffect(panelScale)
        }
        .frame(width: canvas.width, height: canvas.height)
    }
}

@MainActor func image(for moment: Moment, at time: Double) -> CGImage {
    let renderer = ImageRenderer(content: Scene(moment: moment, time: time))
    renderer.scale = renderScale
    return renderer.cgImage!
}

MainActor.assumeIsolated {
    let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
    var frames: [CGImage] = []
    var time = 0.0
    for moment in moments {
        let count = Int(moment.seconds * framesPerSecond)
        for _ in 0..<count {
            frames.append(image(for: moment, at: time))
            time += 1 / framesPerSecond
        }
    }

    let gifURL = outputDirectory.appendingPathComponent("demo.gif") as CFURL
    let destination = CGImageDestinationCreateWithURL(gifURL, UTType.gif.identifier as CFString, frames.count, nil)!
    CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / framesPerSecond]] as CFDictionary
    for frame in frames { CGImageDestinationAddImage(destination, frame, frameProperties) }
    guard CGImageDestinationFinalize(destination) else { fatalError("could not write the GIF") }

    if CommandLine.arguments.count > 2 {
        let framesDirectory = URL(fileURLWithPath: CommandLine.arguments[2])
        for (index, frame) in frames.enumerated() {
            let png = NSBitmapImageRep(cgImage: frame).representation(using: .png, properties: [:])!
            try! png.write(to: framesDirectory.appendingPathComponent(String(format: "frame-%03d.png", index)))
        }
    }

    print("frames: \(frames.count)")
}
