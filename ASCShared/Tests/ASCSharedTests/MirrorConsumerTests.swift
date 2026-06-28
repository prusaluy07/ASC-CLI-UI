import XCTest
import ASCShared

/// Tests the pure Phase 3b consumer logic (record-field → snapshot, summary decode, and
/// grouping/latest selection). CloudKit I/O is intentionally kept out of these helpers so
/// they stay platform-pure and testable.
final class MirrorConsumerTests: XCTestCase {

    private func date(_ offset: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: offset)
    }

    // MARK: - makeSnapshot

    func testMakeSnapshotFromInlinePayload() {
        let fields = SnapshotFields(appId: "123", section: "status",
                                    schemaVersion: 1, capturedAt: date(0),
                                    summaryJSON: #"{"health":"READY"}"#,
                                    payloadIsAsset: false,
                                    inlinePayloadJSON: #"{"a":1}"#)
        let snap = RemoteMirror.makeSnapshot(from: fields, assetPayloadJSON: nil)
        XCTAssertEqual(snap?.appId, "123")
        XCTAssertEqual(snap?.section, "status")
        XCTAssertEqual(snap?.payloadJSON, #"{"a":1}"#)
        XCTAssertEqual(snap?.summary?["health"], "READY")
    }

    func testMakeSnapshotFromAsset() {
        let fields = SnapshotFields(appId: "123", section: "versions",
                                    schemaVersion: 1, capturedAt: date(0),
                                    payloadIsAsset: true,
                                    inlinePayloadJSON: nil)
        let snap = RemoteMirror.makeSnapshot(from: fields, assetPayloadJSON: #"{"big":true}"#)
        XCTAssertEqual(snap?.payloadJSON, #"{"big":true}"#)
    }

    func testMakeSnapshotReturnsNilWhenAssetMissing() {
        let fields = SnapshotFields(appId: "123", section: "versions",
                                    schemaVersion: 1, capturedAt: date(0),
                                    payloadIsAsset: true,
                                    inlinePayloadJSON: nil)
        XCTAssertNil(RemoteMirror.makeSnapshot(from: fields, assetPayloadJSON: nil))
    }

    func testMakeSnapshotInlineMissingPayloadDefaultsToEmpty() {
        let fields = SnapshotFields(appId: "123", section: "builds",
                                    schemaVersion: 1, capturedAt: date(0),
                                    payloadIsAsset: false,
                                    inlinePayloadJSON: nil)
        XCTAssertEqual(RemoteMirror.makeSnapshot(from: fields, assetPayloadJSON: nil)?.payloadJSON, "")
    }

    // MARK: - decodeSummary

    func testDecodeSummaryStringsAndNumbers() {
        let summary = RemoteMirror.decodeSummary(#"{"count":3,"latestVersion":"2.0.0"}"#)
        XCTAssertEqual(summary?["count"], "3")
        XCTAssertEqual(summary?["latestVersion"], "2.0.0")
    }

    func testDecodeSummaryDefensiveOnGarbage() {
        XCTAssertNil(RemoteMirror.decodeSummary("not json"))
        XCTAssertNil(RemoteMirror.decodeSummary("{}"))
    }

    // MARK: - group

    func testGroupBucketsByAppId() {
        let snaps = [
            Snapshot(appId: "a", section: "status", capturedAt: date(0), payloadJSON: "{}"),
            Snapshot(appId: "a", section: "builds", capturedAt: date(0), payloadJSON: "{}"),
            Snapshot(appId: "b", section: "status", capturedAt: date(0), payloadJSON: "{}")
        ]
        let groups = RemoteMirror.group(snaps)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.map(\.appId), ["a", "b"]) // sorted
        XCTAssertEqual(groups[0].snapshots.count, 2)
        XCTAssertEqual(groups[1].snapshots.count, 1)
    }

    func testGroupKeepsLatestPerSection() {
        let old = Snapshot(appId: "a", section: "status", capturedAt: date(0),
                           payloadJSON: #"{"v":"old"}"#)
        let new = Snapshot(appId: "a", section: "status", capturedAt: date(100),
                           payloadJSON: #"{"v":"new"}"#)
        let groups = RemoteMirror.group([old, new])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].snapshots[.status]?.payloadJSON, #"{"v":"new"}"#)
    }

    func testGroupIgnoresUnknownSection() {
        let snaps = [
            Snapshot(appId: "a", section: "status", capturedAt: date(0), payloadJSON: "{}"),
            Snapshot(appId: "a", section: "bogus", capturedAt: date(0), payloadJSON: "{}")
        ]
        let groups = RemoteMirror.group(snaps)
        XCTAssertEqual(groups.first?.snapshots.count, 1)
        XCTAssertNotNil(groups.first?.snapshots[.status])
    }

    func testGroupLastUpdatedIsMaxCapturedAt() {
        let snaps = [
            Snapshot(appId: "a", section: "status", capturedAt: date(10), payloadJSON: "{}"),
            Snapshot(appId: "a", section: "builds", capturedAt: date(50), payloadJSON: "{}")
        ]
        XCTAssertEqual(RemoteMirror.group(snaps).first?.lastUpdated, date(50))
    }

    func testOrderedSectionsFollowAllCasesOrder() {
        let snaps = [
            Snapshot(appId: "a", section: "builds", capturedAt: date(0), payloadJSON: "{}"),
            Snapshot(appId: "a", section: "status", capturedAt: date(0), payloadJSON: "{}")
        ]
        // status precedes builds in MirrorSection.allCases regardless of input order.
        XCTAssertEqual(RemoteMirror.group(snaps).first?.orderedSections, [.status, .builds])
    }

    // MARK: - latest

    func testLatestPicksMostRecent() {
        let snaps = [
            Snapshot(appId: "a", section: "status", capturedAt: date(0), payloadJSON: "{}"),
            Snapshot(appId: "a", section: "status", capturedAt: date(999), payloadJSON: "{}"),
            Snapshot(appId: "a", section: "status", capturedAt: date(5), payloadJSON: "{}")
        ]
        XCTAssertEqual(RemoteMirror.latest(snaps)?.capturedAt, date(999))
        XCTAssertNil(RemoteMirror.latest([]))
    }
}
