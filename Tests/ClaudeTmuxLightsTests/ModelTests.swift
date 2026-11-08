import Foundation
import Testing
@testable import ClaudeTmuxLights

struct ModelTests {
    private func frame(_ claudes: String) -> Data { Data(#"{"claudes":[\#(claudes)]}"#.utf8) }

    @Test func decodesSessionAndWindowIntoIDAndLabel() throws {
        let claudes = try #require(parseFrame(frame(#"{"session":"work","window":2,"status":"busy"}"#)))
        let claude = try #require(claudes.first)
        #expect(claude.id == "work:2")
        #expect(claude.label == "2")
        #expect(claude.group == "work")
        #expect(claude.status == .busy)
    }

    @Test func unknownStatusFallsBackToUnknown() throws {
        let claudes = try #require(parseFrame(frame(#"{"id":"a","label":"1","group":"g","status":"asleep"}"#)))
        #expect(claudes.first?.status == .unknown)
    }

    @Test func skipsEntriesThatCannotBeDecoded() throws {
        let claudes = try #require(parseFrame(frame(#"{"status":"busy"},{"id":"a","label":"1","status":"idle"}"#)))
        #expect(claudes.map(\.id) == ["a"])
    }

    @Test func sortsByGroupThenWindow() throws {
        let json = #"{"session":"b","window":1,"status":"idle"},{"session":"a","window":10,"status":"idle"},{"session":"a","window":2,"status":"idle"}"#
        let claudes = try #require(parseFrame(frame(json)))
        #expect(claudes.map(\.id) == ["a:2", "a:10", "b:1"])
    }

    @Test func rejectsMalformedLines() {
        #expect(parseFrame(Data("not json".utf8)) == nil)
    }

    @Test func tooltipNamesThePlaceWhenThereIsOne() throws {
        let claude = try #require(parseFrame(frame(#"{"session":"work","window":1,"status":"waiting"}"#))?.first)
        #expect(PlacedClaude(claude: claude, placeID: "p", placeName: "").tooltip == "work:1 waiting")
        #expect(PlacedClaude(claude: claude, placeID: "p", placeName: "VM").tooltip == "work:1 waiting (VM)")
    }
}

struct ConnectionTests {
    @Test func parsesEachKind() {
        #expect(Connection("local") == .local)
        #expect(Connection(" LOCAL ") == .local)
        #expect(Connection("127.0.0.1:47500") == .tcp(host: "127.0.0.1", port: 47500))
        #expect(Connection("ssh:me@box") == .ssh(host: "me@box"))
    }

    @Test func rejectsBadInput() {
        #expect(Connection("") == nil)
        #expect(Connection("host") == nil)
        #expect(Connection("host:0") == nil)
        #expect(Connection("host:99999") == nil)
        #expect(Connection("ssh:") == nil)
        #expect(Connection("ssh:-oProxyCommand=x") == nil)
        #expect(Connection("ssh:two words") == nil)
    }
}
