import AppKit
import SwiftUI

let canvas: CGFloat = 1024
let tile: CGFloat = 824
let tileRadius: CGFloat = 185
let orbSize: CGFloat = 400
let orbTop = Color(hex: 0xE88F6F)
let orbBottom = Color(hex: 0xCF6A47)

struct IconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x23262D), Color(hex: 0x0D0E11)], startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.03)], startPoint: .top, endPoint: .bottom), lineWidth: 4)
                )
                .frame(width: tile, height: tile)

            Circle()
                .fill(LinearGradient(colors: [orbTop, orbBottom], startPoint: .top, endPoint: .bottom))
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0)], startPoint: .top, endPoint: .center),
                        lineWidth: 6
                    )
                )
                .overlay(Circle().strokeBorder(.black.opacity(0.18), lineWidth: 3))
                .shadow(color: .black.opacity(0.45), radius: 26, y: 16)
                .frame(width: orbSize, height: orbSize)
        }
        .frame(width: canvas, height: canvas)
    }
}

MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: IconView())
    renderer.scale = 1
    guard let image = renderer.cgImage else { fatalError("could not render icon") }
    let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
