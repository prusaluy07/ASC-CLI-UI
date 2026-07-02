import XCTest
import ASCShared

final class ModelDecodingTests: XCTestCase {

    // MARK: - ASCJSONList.decode

    func testEnvelopeDecodesItemsAndPaging() throws {
        let json = """
        {
          "data": [
            { "type": "apps", "id": "1", "attributes": { "name": "One", "bundleId": "com.x.one" } },
            { "type": "apps", "id": "2", "attributes": { "name": "Two", "bundleId": "com.x.two" } }
          ],
          "meta": { "paging": { "total": 240, "limit": 2 } }
        }
        """
        let (items, paging) = try ASCJSONList.decode(json, as: ASCApp.self)
        XCTAssertEqual(items.map(\.id), ["1", "2"])
        XCTAssertEqual(items.first?.name, "One")
        XCTAssertEqual(paging?.total, 240)
        XCTAssertEqual(paging?.limit, 2)
    }

    func testEmptyDataArrayIsNotAnError() throws {
        let (items, _) = try ASCJSONList.decode(#"{ "data": [] }"#, as: ASCApp.self)
        XCTAssertTrue(items.isEmpty)
    }

    func testBareArrayFallback() throws {
        let json = """
        [ { "type": "apps", "id": "1", "attributes": { "name": "One", "bundleId": "com.x.one" } } ]
        """
        let (items, paging) = try ASCJSONList.decode(json, as: ASCApp.self)
        XCTAssertEqual(items.count, 1)
        XCTAssertNil(paging)
    }

    func testErrorsDocumentThrowsAPIError() {
        let json = """
        {
          "errors": [
            { "status": "403", "code": "FORBIDDEN",
              "title": "Access forbidden", "detail": "The API key lacks permission." }
          ]
        }
        """
        XCTAssertThrowsError(try ASCJSONList.decode(json, as: ASCApp.self)) { error in
            guard case ASCDecodeError.api(let message) = error else {
                return XCTFail("Expected .api, got \(error)")
            }
            XCTAssertTrue(message.contains("Access forbidden"))
            XCTAssertTrue(message.contains("lacks permission"))
        }
    }

    func testNonJSONOutputThrowsMalformed() {
        XCTAssertThrowsError(try ASCJSONList.decode("Error: boom", as: ASCApp.self)) { error in
            guard case ASCDecodeError.malformed = error else {
                return XCTFail("Expected .malformed, got \(error)")
            }
        }
    }

    func testEmptyOutputThrowsMalformed() {
        XCTAssertThrowsError(try ASCJSONList.decode("  \n", as: ASCApp.self)) { error in
            guard case ASCDecodeError.malformed = error else {
                return XCTFail("Expected .malformed, got \(error)")
            }
        }
    }

    // MARK: - Flexible bool attributes (ASCBetaGroup)

    private func group(attributes: String) throws -> ASCBetaGroup {
        let json = """
        { "data": [ { "type": "betaGroups", "id": "g1", "attributes": \(attributes) } ] }
        """
        let (items, _) = try ASCJSONList.decode(json, as: ASCBetaGroup.self)
        return try XCTUnwrap(items.first)
    }

    func testBetaGroupNativeBools() throws {
        let g = try group(attributes:
            #"{ "name": "Internal", "isInternalGroup": true, "feedbackEnabled": false }"#)
        XCTAssertTrue(g.isInternal)
        XCTAssertFalse(g.feedbackEnabled)
        XCTAssertFalse(g.hasAccessToAllBuilds)   // missing attribute keeps its fallback
    }

    func testBetaGroupStringBools() throws {
        let g = try group(attributes:
            #"{ "name": "Internal", "isInternalGroup": "true", "hasAccessToAllBuilds": "1", "feedbackEnabled": "false" }"#)
        XCTAssertTrue(g.isInternal)
        XCTAssertTrue(g.hasAccessToAllBuilds)
        XCTAssertFalse(g.feedbackEnabled)
    }

    func testBetaGroupNumericBools() throws {
        let g = try group(attributes:
            #"{ "name": "G", "isInternalGroup": 1, "feedbackEnabled": 0 }"#)
        XCTAssertTrue(g.isInternal)
        XCTAssertFalse(g.feedbackEnabled)
    }
}
