import AppKit
import SwiftUI

struct PanelStyle: Equatable {
    var vertical = false
    var showBackground = false
    var showPlaceLabel = false
    var showSessionLabel = false

    var showsCaptions: Bool { showPlaceLabel || showSessionLabel }
}

struct LightBar: View {
    let entries: [Entry]
    let style: PanelStyle

    @Environment(\.panelTheme) private var theme

    var body: some View {
        stack { content }
            .animation(.easeInOut(duration: 0.25), value: entries)
            .padding(Metrics.padding)
            .background { caseBackground }
            .padding(Metrics.glowMargin)
            .fixedSize()
    }

    private func stack<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let layout = style.vertical
            ? AnyLayout(VStackLayout(spacing: Metrics.spacing))
            : AnyLayout(HStackLayout(spacing: Metrics.spacing))
        return layout { content() }
    }

    @ViewBuilder private var caseBackground: some View {
        if style.showBackground {
            switch theme.finish {
            case .glass: glassCase
            case .signal: SignalBackplate()
            case .solid, .jewel: solidCase
            }
        } else {
            Capsule(style: .continuous).fill(Color.black.opacity(0.01))
        }
    }

    private var solidCase: some View {
        ZStack {
            Capsule(style: .continuous).fill(.ultraThinMaterial)
            Capsule(style: .continuous).fill(theme.caseFill.opacity(0.82))
            Capsule(style: .continuous).strokeBorder(
                LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                lineWidth: 1
            )
        }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private var glassCase: some View {
        if #available(macOS 26, *) {
            Color.clear.glassEffect(.regular, in: Capsule(style: .continuous))
        } else {
            ZStack {
                Capsule(style: .continuous).fill(.ultraThinMaterial)
                Capsule(style: .continuous).strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            }
        }
    }

    private func captionText(for group: LampGroup) -> String {
        var parts: [String] = []
        if style.showPlaceLabel, !group.place.isEmpty { parts.append(group.place) }
        if style.showSessionLabel, let session = group.session, !session.isEmpty { parts.append(session) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var content: some View {
        if entries.isEmpty {
            Circle()
                .fill(Color.gray.opacity(0.6))
                .frame(width: 6, height: 6)
                .frame(width: Metrics.socketSize, height: Metrics.socketSize)
        } else {
            ForEach(panelItems(for: entries)) { item in
                switch item {
                case .group(let group): groupView(group)
                case .seam: seam
                }
            }
        }
    }

    private func groupView(_ group: LampGroup) -> some View {
        VStack(spacing: Metrics.captionGap) {
            stack {
                ForEach(group.entries) { lamp($0) }
            }
            if style.showsCaptions { caption(captionText(for: group)) }
        }
    }

    @ViewBuilder private func lamp(_ entry: Entry) -> some View {
        switch entry {
        case .claude(let placed):
            OrbView(look: Look(placed.claude.status), label: placed.claude.label, tooltip: entry.tooltip)
                .zIndex(placed.claude.status == .waiting ? 0 : 1)
        case .offline:
            OrbView(look: .down, label: "–", tooltip: entry.tooltip)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text.isEmpty ? " " : text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(style.showBackground && theme.finish == .glass ? Color.primary : .white)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(.black.opacity(text.isEmpty || style.showBackground ? 0 : 0.55)))
    }

    private var seam: some View {
        Capsule()
            .fill(theme.seam)
            .frame(
                width: style.vertical ? Metrics.seamLength : Metrics.seamThickness,
                height: style.vertical ? Metrics.seamThickness : Metrics.seamLength
            )
    }
}

struct PanelView: View {
    @ObservedObject var hub: StreamHub
    @ObservedObject var prefs: Preferences
    let openSettings: () -> Void
    let onSize: (CGSize) -> Void

    var body: some View {
        LightBar(entries: hub.entries, style: prefs.style)
            .environment(\.panelTheme, PanelTheme.named(prefs.theme))
            .onGeometryChange(for: CGSize.self) { $0.size } action: { onSize($0) }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .contextMenu {
                if prefs.places.count > 1 {
                    Menu("Show") {
                        ForEach($prefs.places) { $place in
                            Toggle(place.name.isEmpty ? "Untitled" : place.name, isOn: $place.enabled)
                        }
                    }
                    Divider()
                }
                Button("Settings…", action: openSettings)
                Divider()
                Button("Quit") { NSApp.terminate(nil) }
            }
    }
}
