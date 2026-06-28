import XCTest
@testable import ASC_CLI_UI

@MainActor
final class PrefetchSettingsTests: XCTestCase {

    func testDefaultRawDecodesToAllSections() {
        let decoded = PrefetchSettings.decode(PrefetchSettings.defaultRaw)
        XCTAssertEqual(decoded, Set(ASCService.PrefetchSection.allCases))
    }

    func testEncodeIsStableAllCasesOrder() {
        let set: Set<ASCService.PrefetchSection> = [.release, .versions]
        // Encoding orders by allCases, not by Set iteration, so it's deterministic.
        XCTAssertEqual(PrefetchSettings.encode(set), "versions,release")
    }

    func testRoundTrip() {
        let set: Set<ASCService.PrefetchSection> = [.builds, .testflight]
        XCTAssertEqual(PrefetchSettings.decode(PrefetchSettings.encode(set)), set)
    }

    func testEmptyAndGarbageInput() {
        XCTAssertTrue(PrefetchSettings.decode("").isEmpty)
        XCTAssertEqual(PrefetchSettings.decode("versions,bogus,builds"),
                       [.versions, .builds])
    }
}
