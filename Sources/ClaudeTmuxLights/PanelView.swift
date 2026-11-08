import AppKit
import SwiftUI

private struct LampGroup: Identifiable {
    let id: String
    let entries: [Entry]
    let place: String
    let session: String?
}

private enum Item: Identifiable {
    case group(LampGroup)
    case seam(String)

    var id: String {
        switch self {
        case .group(let group): group.id
        case .seam(let before): "seam-before-\(before)"
        }
    }
}

struct LightBar: View {
    let entries: [Entry]
    let vertical: Bool
    let showBackground: Bool
    let showPlaceLabel: Bool
    let showSessionLabel: Bool

    private var showsCaptions: Bool { showPlaceLabel || showSessionLabel }

    var body: some View {
        stack { content }
            .animation(.easeInOut(duration: 0.25), value: entries)
            .padding(Theme.padding)
            .background { caseBackground }
            .padding(Theme.glowMargin)
            .fixedSize()
    }

    private func stack<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let layout = vertical
            ? AnyLayout(VStackLayout(spacing: Theme.spacing))
            : AnyLayout(HStackLayout(spacing: Theme.spacing))
        return layout { content() }
    }

    @ViewBuilder private var caseBackground: some View {
        if showBackground {
            ZStack {
                Capsule(style: .continuous).fill(.ultraThinMaterial)
                Capsule(style: .continuous).fill(Theme.caseFill.opacity(0.82))
                Capsule(style: .continuous).strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            }
            .environment(\.colorScheme, .dark)
        } else {
            Capsule(style: .continuous).fill(Color.black.opacity(0.01))
        }
    }

    private var items: [Item] {
        var result: [Item] = []
        var current: [Entry] = []
        var currentKey: String?

        func flush() {
            guard let first = current.first else { return }
            let group: LampGroup
            switch first {
            case .claude(let claude):
                group = LampGroup(id: first.groupKey, entries: current, place: claude.placeName, session: claude.group)
            case .offline(_, let placeName, _):
                group = LampGroup(id: first.groupKey, entries: current, place: placeName, session: nil)
            }
            if !result.isEmpty { result.append(.seam(group.id)) }
            result.append(.group(group))
            current = []
        }

        for entry in entries {
            if let currentKey, currentKey != entry.groupKey { flush() }
            current.append(entry)
            currentKey = entry.groupKey
        }
        flush()
        return result
    }

    private func captionText(for group: LampGroup) -> String {
        var parts: [String] = []
        if showPlaceLabel, !group.place.isEmpty { parts.append(group.place) }
        if showSessionLabel, let session = group.session, !session.isEmpty { parts.append(session) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var content: some View {
        if entries.isEmpty {
            Circle()
                .fill(Color.gray.opacity(0.6))
                .frame(width: 6, height: 6)
                .frame(width: Theme.socketSize, height: Theme.socketSize)
        } else {
            ForEach(items) { item in
                switch item {
                case .group(let group): groupView(group)
                case .seam: seam
                }
            }
        }
    }

    private func groupView(_ group: LampGroup) -> some View {
        VStack(spacing: Theme.captionGap) {
            stack {
                ForEach(group.entries) { lamp($0) }
            }
            if showsCaptions { caption(captionText(for: group)) }
        }
    }

    @ViewBuilder private func lamp(_ entry: Entry) -> some View {
        switch entry {
        case .claude(let claude):
            OrbView(look: Look(claude.kind), label: claude.label, tooltip: claude.tooltip)
                .zIndex(claude.kind == .waiting ? 0 : 1)
        case .offline(_, _, let tooltip):
            OrbView(look: .down, label: "–", tooltip: tooltip)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text.isEmpty ? " " : text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(.black.opacity(text.isEmpty || showBackground ? 0 : 0.55)))
    }

    private var seam: some View {
        Capsule()
            .fill(Theme.seam)
            .frame(
                width: vertical ? Theme.seamLength : Theme.seamThickness,
                height: vertical ? Theme.seamThickness : Theme.seamLength
            )
    }
}

struct PanelView: View {
    @ObservedObject var hub: StreamHub
    @ObservedObject var prefs: Preferences
    let openSettings: () -> Void
    let onSize: (CGSize) -> Void

    var body: some View {
        LightBar(
            entries: hub.entries,
            vertical: prefs.vertical,
            showBackground: prefs.showBackground,
            showPlaceLabel: prefs.showPlaceLabel,
            showSessionLabel: prefs.showSessionLabel
        )
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
