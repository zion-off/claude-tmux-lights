import AppKit
import AVFoundation
import CoreImage
import ImageIO
import SwiftUI

// Renders a video that shows each theme in turn on a patch of desktop, using the app's own panel views.
// Usage: make-showcase <wallpaper.heic> <output.mp4> [--no-captions] [--4k | --readme]

/// --readme renders the wide strip at the top of the README, which is turned into a GIF afterwards.
let readme = CommandLine.arguments.contains("--readme")
/// The patch of desktop in view, in points. The panel keeps its real size against the wallpaper; rendering
/// past Retina 2x just zooms in on that patch so the panel is easier to see.
let canvas = readme ? CGSize(width: 432.5, height: 125) : CGSize(width: 768, height: 432)
/// 1920x1080, 3840x2160 with --4k, or 1038x300 with --readme.
let renderScale: CGFloat = readme ? 2.4 : CommandLine.arguments.contains("--4k") ? 5 : 2.5
let bitRate = CommandLine.arguments.contains("--4k") ? 80_000_000 : 24_000_000
/// The screen the wallpaper is scaled to fill, in points, as on a 16-inch MacBook Pro.
let screen = CGSize(width: 1728, height: 1117)
/// Which part of the screen is in view, from 0 to 1 on each axis.
let focus = CGPoint(x: 0.55, y: 1)

let framesPerSecond = readme ? 15 : 60
let segmentSeconds = 4.5
let themeFadeSeconds = 0.6

typealias Host = (id: String, name: String)
let thisMac: Host = ("mac", "This Mac")
let vm: Host = ("vm", "VM")
let mini: Host = ("mini", "Mac mini")
let devbox: Host = ("devbox", "devbox")

func lamp(_ place: Host, _ label: String, _ status: String) -> Entry {
    let json = #"{"claudes":[{"id":"@\#(label)","group":"work","label":"\#(label)","status":"\#(status)"}]}"#
    return .claude(PlacedClaude(claude: parseFrame(Data(json.utf8))!.first!, placeID: place.id, placeName: place.name))
}

func offline(_ place: Host) -> Entry {
    .offline(placeID: place.id, placeName: place.name, reason: .disconnected)
}

/// What each theme shows, in the order of PanelTheme.all. A theme's lamps hold their states while it is
/// on screen, so the only change is the theme itself; between them, every state appears somewhere.
let lineups: [[Entry]] = [
    // Default
    [lamp(thisMac, "1", "busy"), lamp(thisMac, "2", "waiting"), lamp(vm, "1", "shell")],
    // Glass
    [lamp(thisMac, "1", "waiting"), lamp(thisMac, "2", "busy"), lamp(thisMac, "3", "idle"), lamp(mini, "1", "busy")],
    // Jewel
    [lamp(thisMac, "1", "busy"), lamp(vm, "1", "idle"), lamp(vm, "2", "waiting"), offline(devbox)],
    // Traffic Light
    [lamp(thisMac, "1", "idle"), lamp(thisMac, "2", "busy"), lamp(mini, "1", "waiting"), lamp(mini, "2", "shell")],
    // Frosted
    [lamp(thisMac, "3", "waiting"), lamp(vm, "1", "busy"), lamp(mini, "2", "idle"), lamp(devbox, "4", "shell")],
]

// MARK: Wallpaper

/// Loads one image from a (possibly dynamic) HEIC, preferring its night variant.
func loadWallpaper(_ path: String) -> CGImage {
    let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
    let index = CGImageSourceGetCount(source) > 1 ? 1 : 0
    let options = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: 8192,
        kCGImageSourceCreateThumbnailWithTransform: true,
    ] as CFDictionary
    return CGImageSourceCreateThumbnailAtIndex(source, index, options)!
}

/// The wallpaper scaled to fill the screen, as macOS does, then cropped to the patch in view.
func preparedWallpaper(_ image: CGImage) -> CGImage {
    let pixelsPerPoint = renderScale
    let fill = max(screen.width / CGFloat(image.width), screen.height / CGFloat(image.height)) * pixelsPerPoint
    let scaled = CIImage(cgImage: image).transformed(by: CGAffineTransform(scaleX: fill, y: fill))
    let view = CGSize(width: canvas.width * pixelsPerPoint, height: canvas.height * pixelsPerPoint)
    // The screen is centered on the scaled wallpaper; the patch sits at the focus point within the screen.
    let screenOrigin = CGPoint(
        x: (scaled.extent.width - screen.width * pixelsPerPoint) / 2,
        y: (scaled.extent.height - screen.height * pixelsPerPoint) / 2
    )
    let x = screenOrigin.x + (screen.width * pixelsPerPoint - view.width) * focus.x
    // Core Image counts y from the bottom.
    let yFromTop = screenOrigin.y + (screen.height * pixelsPerPoint - view.height) * focus.y
    let y = scaled.extent.height - yFromTop - view.height
    return CIContext().createCGImage(scaled, from: CGRect(x: x, y: y, width: view.width, height: view.height))!
}

// MARK: Scene

struct Shot: View {
    let theme: PanelTheme
    let entries: [Entry]

    var body: some View {
        LightBar(entries: entries, style: PanelStyle(showPlaceLabel: true))
            .environment(\.panelTheme, theme)
    }
}

struct Caption: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.system(size: readme ? 9 : 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, readme ? 8 : 12)
            .padding(.vertical, readme ? 4 : 6)
            .background(Capsule().fill(.black.opacity(0.35)))
            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
    }
}

struct Scene: View {
    let current: Shot
    let outgoing: Shot?
    let themeFade: Double
    let captions: Bool
    let pulse: Double
    let wallpaper: Image

    var body: some View {
        ZStack {
            wallpaper.resizable().frame(width: canvas.width, height: canvas.height)
            if let outgoing { outgoing.opacity(1 - themeFade) }
            current.opacity(outgoing == nil ? 1 : themeFade)
            if captions {
                // The README strip is short, so its caption goes up top, clear of wide panels.
                ZStack(alignment: readme ? .topLeading : .bottomLeading) {
                    Color.clear
                    if let outgoing { Caption(name: outgoing.theme.name).opacity(1 - themeFade) }
                    Caption(name: current.theme.name).opacity(outgoing == nil ? 1 : themeFade)
                }
                .padding(readme ? 10 : 22)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .environment(\.pulseOverride, pulse)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: Encoding

@MainActor func frame(at time: Double, captions: Bool, wallpaper: Image) -> CGImage {
    let themes = PanelTheme.all
    let segment = min(Int(time / segmentSeconds), themes.count - 1)
    let local = time - Double(segment) * segmentSeconds
    // Each theme fades in over the end of the one before; the first fades in from the last, so it loops.
    let fading = local < themeFadeSeconds
    let previous = (segment + themes.count - 1) % themes.count
    let phase = 0.5 + 0.5 * sin(time * 2 * .pi / Motion.pulsePeriod)
    let scene = Scene(
        current: Shot(theme: themes[segment], entries: lineups[segment]),
        outgoing: fading ? Shot(theme: themes[previous], entries: lineups[previous]) : nil,
        themeFade: local / themeFadeSeconds,
        captions: captions,
        pulse: phase * phase * (3 - 2 * phase),
        wallpaper: wallpaper
    )
    let renderer = ImageRenderer(content: scene)
    renderer.scale = renderScale
    return renderer.cgImage!
}

func pixelBuffer(from image: CGImage, pool: CVPixelBufferPool) -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
    let pixels = buffer!
    CVPixelBufferLockBaseAddress(pixels, [])
    let context = CGContext(
        data: CVPixelBufferGetBaseAddress(pixels),
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(pixels),
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    )!
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    CVPixelBufferUnlockBaseAddress(pixels, [])
    return pixels
}

MainActor.assumeIsolated {
    let arguments = CommandLine.arguments
    guard arguments.count >= 3 else { fatalError("usage: make-showcase <wallpaper.heic> <output.mp4> [--no-captions] [--4k]") }
    precondition(lineups.count == PanelTheme.all.count, "every theme needs a lineup")
    let captions = !arguments.contains("--no-captions")
    let wallpaper = Image(decorative: preparedWallpaper(loadWallpaper(arguments[1])), scale: renderScale)

    let output = URL(fileURLWithPath: arguments[2])
    try? FileManager.default.removeItem(at: output)
    let width = Int(canvas.width * renderScale), height = Int(canvas.height * renderScale)
    let writer = try! AVAssetWriter(outputURL: output, fileType: .mp4)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoColorPropertiesKey: [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ],
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: bitRate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        ],
    ])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
    ])
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    let count = Int(segmentSeconds * Double(PanelTheme.all.count) * Double(framesPerSecond))
    for index in 0..<count {
        let image = autoreleasepool { frame(at: Double(index) / Double(framesPerSecond), captions: captions, wallpaper: wallpaper) }
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
        let time = CMTime(value: CMTimeValue(index), timescale: CMTimeScale(framesPerSecond))
        adaptor.append(pixelBuffer(from: image, pool: adaptor.pixelBufferPool!), withPresentationTime: time)
        if index % 60 == 0 { print("frame \(index)/\(count)") }
    }
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    if writer.status != .completed { fatalError("could not write the video: \(String(describing: writer.error))") }
    print(output.path)
}
