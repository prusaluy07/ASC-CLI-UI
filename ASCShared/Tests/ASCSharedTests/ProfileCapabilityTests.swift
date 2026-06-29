import XCTest
@testable import ASCShared

final class ProfileCapabilityTests: XCTestCase {

    func testEncodeDecodeRoundTrip() {
        let map: [ProfileCapability: String] = [
            .analytics: "Admin Key",
            .finance: "Finance Key",
            .admin: "Team Admin"
        ]
        let raw = ProfileCapabilitySettings.encode(map)
        let decoded = ProfileCapabilitySettings.decode(raw)
        XCTAssertEqual(decoded, map)
    }

    func testDecodeEmptyAndInvalid() {
        XCTAssertEqual(ProfileCapabilitySettings.decode(""), [:])
        XCTAssertEqual(ProfileCapabilitySettings.decode("not json"), [:])
        XCTAssertEqual(ProfileCapabilitySettings.decode(#"{"unknown": "x"}"#), [:])
    }

    func testPruneRemovesStaleNames() {
        let map: [ProfileCapability: String] = [
            .analytics: "gone",
            .finance: "still-here"
        ]
        let pruned = ProfileCapabilitySettings.prune(map, validNames: ["still-here"])
        XCTAssertEqual(pruned, [.finance: "still-here"])
    }

    func testAssignableExcludesGeneral() {
        XCTAssertFalse(ProfileCapability.assignable.contains(.general))
        XCTAssertEqual(ProfileCapability.assignable.count, 3)
    }
}
