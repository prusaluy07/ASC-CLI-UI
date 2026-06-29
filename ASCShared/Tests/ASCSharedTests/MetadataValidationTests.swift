import XCTest
@testable import ASCShared

final class MetadataValidationTests: XCTestCase {

    func testParsesValidateResult() {
        let json = #"""
        {"dir":"/Users/x/Voicement","filesScanned":0,"issues":[{"scope":"metadata","file":"/Users/x/Voicement","field":"metadata","severity":"error","message":"no metadata .json files found"}],"errorCount":1,"warningCount":0,"valid":false}
        """#
        let v = MetadataValidation.parse(json)
        XCTAssertNotNil(v)
        XCTAssertEqual(v?.dir, "/Users/x/Voicement")
        XCTAssertEqual(v?.filesScanned, 0)
        XCTAssertEqual(v?.errorCount, 1)
        XCTAssertEqual(v?.warningCount, 0)
        XCTAssertEqual(v?.valid, false)
        XCTAssertEqual(v?.issues?.count, 1)
        XCTAssertEqual(v?.issues?.first?.isError, true)
        XCTAssertEqual(v?.issues?.first?.message, "no metadata .json files found")
    }

    func testOrdersErrorsBeforeWarnings() {
        let json = #"""
        {"valid":false,"issues":[
          {"severity":"warning","message":"w1"},
          {"severity":"error","message":"e1"},
          {"severity":"warning","message":"w2"}
        ]}
        """#
        let v = MetadataValidation.parse(json)
        XCTAssertEqual(v?.orderedIssues.map(\.message), ["e1", "w1", "w2"])
    }

    func testReturnsNilForUnrelatedJSON() {
        XCTAssertNil(MetadataValidation.parse(#"{"data":[{"id":"1"}]}"#))
        XCTAssertNil(MetadataValidation.parse("not json"))
    }
}
