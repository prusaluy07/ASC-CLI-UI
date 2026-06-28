import XCTest
import ASCShared

final class RemoteMirrorTests: XCTestCase {

    // MARK: - Record naming

    func testRecordNameFormat() {
        XCTAssertEqual(RemoteMirror.recordName(appId: "123", section: "status"), "123:status")
        XCTAssertEqual(RemoteMirror.recordName(appId: "abc", section: .versions), "abc:versions")
    }

    // MARK: - Asset threshold

    func testAssetThresholdDecision() {
        XCTAssertFalse(RemoteMirror.shouldUseAsset(payloadByteCount: 0))
        XCTAssertFalse(RemoteMirror.shouldUseAsset(payloadByteCount: RemoteMirror.assetThresholdBytes))
        XCTAssertTrue(RemoteMirror.shouldUseAsset(payloadByteCount: RemoteMirror.assetThresholdBytes + 1))
    }

    func testAssetThresholdCustom() {
        XCTAssertTrue(RemoteMirror.shouldUseAsset(payloadByteCount: 11, threshold: 10))
        XCTAssertFalse(RemoteMirror.shouldUseAsset(payloadByteCount: 10, threshold: 10))
    }

    func testPayloadByteCountIsUTF8() {
        XCTAssertEqual(RemoteMirror.payloadByteCount("abc"), 3)
        XCTAssertEqual(RemoteMirror.payloadByteCount("é"), 2) // 2 UTF-8 bytes
    }

    // MARK: - Selection encode/decode

    func testSelectionRoundTrip() {
        let set: Set<MirrorSection> = [.builds, .status]
        XCTAssertEqual(MirrorSection.decode(MirrorSection.encode(set)), set)
    }

    func testSelectionEncodeIsStableAllCasesOrder() {
        // Encoding always follows allCases order (status before builds), not Set order.
        let set: Set<MirrorSection> = [.builds, .status]
        XCTAssertEqual(MirrorSection.encode(set), "status,builds")
    }

    func testSelectionDecodeIgnoresGarbage() {
        XCTAssertTrue(MirrorSection.decode("").isEmpty)
        XCTAssertEqual(MirrorSection.decode("status,bogus,builds"), [.status, .builds])
    }

    func testDefaultRawDecodesToDefaultSelection() {
        XCTAssertEqual(MirrorSection.decode(MirrorSection.defaultRaw), MirrorSection.defaultSelection)
    }

    // MARK: - Sync interval

    func testSyncIntervalSeconds() {
        XCTAssertEqual(SyncInterval.every15Minutes.seconds, 900)
        XCTAssertEqual(SyncInterval.hourly.seconds, 3600)
        XCTAssertEqual(SyncInterval.every6Hours.seconds, 21600)
        XCTAssertEqual(SyncInterval.daily.seconds, 86400)
    }

    // MARK: - Summary extraction

    func testStatusSummary() {
        let json = """
        {
          "summary": { "health": "GREEN", "nextAction": "Submit for review" },
          "builds": { "latest": { "buildNumber": "42" } },
          "appstore": { "state": "READY_FOR_SALE" },
          "review": { "state": "APPROVED" }
        }
        """
        let s = RemoteMirror.summarize(section: .status, payloadJSON: json)
        XCTAssertEqual(s["health"], "GREEN")
        XCTAssertEqual(s["nextAction"], "Submit for review")
        XCTAssertEqual(s["latestBuild"], "42")
        XCTAssertEqual(s["appStoreState"], "READY_FOR_SALE")
        XCTAssertEqual(s["reviewState"], "APPROVED")
    }

    func testVersionsSummaryFromJSONAPI() {
        let json = """
        {
          "data": [
            { "id": "1", "type": "appStoreVersions",
              "attributes": { "versionString": "2.1.0", "appStoreState": "PREPARE_FOR_SUBMISSION" } },
            { "id": "2", "type": "appStoreVersions",
              "attributes": { "versionString": "2.0.0", "appStoreState": "READY_FOR_SALE" } }
          ]
        }
        """
        let s = RemoteMirror.summarize(section: .versions, payloadJSON: json)
        XCTAssertEqual(s["count"], "2")
        XCTAssertEqual(s["latestVersion"], "2.1.0")
        XCTAssertEqual(s["latestState"], "PREPARE_FOR_SUBMISSION")
    }

    func testBuildsSummaryUsesVersionAttributeAsBuildNumber() {
        let json = """
        { "data": [ { "id": "9", "attributes": { "version": "317", "processingState": "VALID" } } ] }
        """
        let s = RemoteMirror.summarize(section: .builds, payloadJSON: json)
        XCTAssertEqual(s["count"], "1")
        XCTAssertEqual(s["latestBuild"], "317")
        XCTAssertEqual(s["latestState"], "VALID")
    }

    func testCollectionSummaryCounts() {
        let json = #"{ "data": [ {"id":"a"}, {"id":"b"}, {"id":"c"} ] }"#
        XCTAssertEqual(RemoteMirror.summarize(section: .betaGroups, payloadJSON: json)["count"], "3")
    }

    func testSummarizeIsDefensiveOnGarbage() {
        XCTAssertTrue(RemoteMirror.summarize(section: .status, payloadJSON: "not json").isEmpty)
        XCTAssertTrue(RemoteMirror.summarize(section: .versions, payloadJSON: "").isEmpty)
    }
}
