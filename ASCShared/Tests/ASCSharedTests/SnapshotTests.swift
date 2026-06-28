import XCTest
import ASCShared

final class SnapshotTests: XCTestCase {

    func testRoundTripPreservesFields() throws {
        let original = Snapshot(
            appId: "123",
            section: "status",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            payloadJSON: #"{"hello":"world"}"#,
            summary: ["health": "GREEN"]
        )
        let restored = try Snapshot.decoded(from: original.encodedString())
        XCTAssertEqual(restored.appId, "123")
        XCTAssertEqual(restored.section, "status")
        XCTAssertEqual(restored.schemaVersion, Snapshot.currentSchemaVersion)
        XCTAssertEqual(restored.capturedAt, original.capturedAt)
        XCTAssertEqual(restored.payloadJSON, #"{"hello":"world"}"#)
        XCTAssertEqual(restored.summary?["health"], "GREEN")
    }

    func testOptionalSummaryDefaultsToNil() throws {
        let snap = Snapshot(appId: "a", section: "builds", payloadJSON: "[]")
        let restored = try Snapshot.decoded(from: try snap.encoded())
        XCTAssertNil(restored.summary)
    }
}
