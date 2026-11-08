import Foundation

struct LampGroup: Identifiable {
    let key: GroupKey
    let entries: [Entry]
    let place: String
    let session: String?

    var id: GroupKey { key }
}

enum PanelItemID: Hashable {
    case group(GroupKey)
    case seam(before: GroupKey)
}

enum PanelItem: Identifiable {
    case group(LampGroup)
    case seam(before: GroupKey)

    var id: PanelItemID {
        switch self {
        case .group(let group): .group(group.key)
        case .seam(let before): .seam(before: before)
        }
    }
}

/// Splits consecutive entries into groups and puts a seam between neighbouring groups.
func panelItems(for entries: [Entry]) -> [PanelItem] {
    var result: [PanelItem] = []
    var current: [Entry] = []

    func flush() {
        guard let first = current.first else { return }
        var session: String?
        if case .claude(let placed) = first { session = placed.claude.group }
        let group = LampGroup(key: first.groupKey, entries: current, place: first.placeName, session: session)
        if !result.isEmpty { result.append(.seam(before: group.key)) }
        result.append(.group(group))
        current = []
    }

    for entry in entries {
        if let last = current.last, last.groupKey != entry.groupKey { flush() }
        current.append(entry)
    }
    flush()
    return result
}
