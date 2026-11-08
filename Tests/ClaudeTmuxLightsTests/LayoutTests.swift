import Foundation
import Testing
@testable import ClaudeTmuxLights

struct LayoutTests {
    private func claude(_ id: String, session: String, place: String = "p") -> Entry {
        let json = #"{"claudes":[{"id":"\#(id)","group":"\#(session)","label":"1","status":"idle"}]}"#
        let parsed = parseFrame(Data(json.utf8))!.first!
        return .claude(PlacedClaude(claude: parsed, placeID: place, placeName: place))
    }

    @Test func groupsConsecutiveEntriesAndSeparatesThemWithSeams() {
        let items = panelItems(for: [claude("a", session: "x"), claude("b", session: "x"), claude("c", session: "y")])
        #expect(items.count == 3)
        guard case .group(let first) = items[0], case .seam = items[1], case .group(let second) = items[2] else {
            Issue.record("expected group, seam, group")
            return
        }
        #expect(first.entries.count == 2)
        #expect(second.session == "y")
    }

    @Test func sameSessionInDifferentPlacesIsTwoGroups() {
        let items = panelItems(for: [claude("a", session: "x", place: "mac"), claude("b", session: "x", place: "vm")])
        #expect(items.count == 3)
    }

    @Test func noEntriesMeansNoItems() {
        #expect(panelItems(for: []).isEmpty)
    }

    @Test func itemIDsAreUnique() {
        let items = panelItems(for: [claude("a", session: "x"), claude("b", session: "y"), claude("c", session: "z")])
        #expect(Set(items.map(\.id)).count == items.count)
    }
}

struct EntryBuilderTests {
    private let mac = Place(name: "Mac", kind: .local)
    private var vm: Place { Place(name: "VM", kind: .ssh, address: "box") }

    private func state(up: Bool, ids: [String] = []) -> StreamState {
        let items = ids.map { #"{"id":"\#($0)","label":"1","group":"g","status":"idle"}"# }.joined(separator: ",")
        let claudes = parseFrame(Data(#"{"claudes":[\#(items)]}"#.utf8)) ?? []
        return StreamState(isUp: up, claudes: claudes)
    }

    @Test func noEnabledPlaceShowsOneHint() {
        var off = mac
        off.enabled = false
        let entries = EntryBuilder.build(places: [off], states: [:])
        #expect(entries == [.offline(placeID: Entry.noPlaceID, placeName: "", reason: .noPlaceEnabled)])
    }

    @Test func placeWithoutAStreamHasABadAddress() {
        let entries = EntryBuilder.build(places: [mac], states: [:])
        #expect(entries == [.offline(placeID: mac.id, placeName: "Mac", reason: .badAddress)])
    }

    @Test func downStreamShowsDisconnected() {
        let entries = EntryBuilder.build(places: [mac], states: [mac.id: state(up: false)])
        #expect(entries == [.offline(placeID: mac.id, placeName: "Mac", reason: .disconnected)])
    }

    @Test func upStreamListsItsClaudesTaggedWithThePlace() {
        let vm = vm
        let entries = EntryBuilder.build(places: [mac, vm], states: [mac.id: state(up: true, ids: ["a"]), vm.id: state(up: true, ids: ["a"])])
        #expect(entries.count == 2)
        #expect(Set(entries.map(\.id)).count == 2)
        #expect(entries.map(\.placeName) == ["Mac", "VM"])
    }

    @Test func skipsDisabledPlaces() {
        var off = vm
        off.enabled = false
        let entries = EntryBuilder.build(places: [mac, off], states: [mac.id: state(up: true, ids: ["a"])])
        #expect(entries.count == 1)
    }
}
