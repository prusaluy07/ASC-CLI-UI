import XCTest
import ASCShared

final class OutputParsingTests: XCTestCase {

    func testNonJSONReturnsNil() {
        XCTAssertNil(ParsedOutput.parse(""))
        XCTAssertNil(ParsedOutput.parse("just some plain text"))
        XCTAssertNil(ParsedOutput.parse("Error: something failed"))
    }

    func testNamedCollectionWithMoneyObjects() throws {
        let json = """
        {
          "subscriptions": [
            { "id": "6777770066", "name": "Premium Monthly", "productId": "com.x.monthly",
              "state": "APPROVED", "currentPrice": { "amount": "3.99", "currency": "USD" } },
            { "id": "6777770536", "name": "Premium Yearly", "productId": "com.x.yearly",
              "state": "APPROVED", "currentPrice": { "amount": "24.99", "currency": "USD" } }
          ]
        }
        """
        let parsed = try XCTUnwrap(ParsedOutput.parse(json))
        XCTAssertEqual(parsed.collection, "subscriptions")
        XCTAssertEqual(parsed.records.count, 2)
        XCTAssertTrue(parsed.preferPretty)

        let first = parsed.records[0]
        XCTAssertEqual(first.title, "Premium Monthly")
        XCTAssertEqual(first.subtitle, "com.x.monthly")
        XCTAssertEqual(first.badge, "APPROVED")
        // The {amount,currency} object collapses into a single money field.
        let price = try XCTUnwrap(first.fields.first { $0.isMoney })
        XCTAssertEqual(price.value, "3.99 USD")
    }

    func testJSONAPIDataWinsOverIncludedAndAttributesFlatten() throws {
        let json = """
        {
          "data": [
            { "type": "apps", "id": "123",
              "attributes": { "name": "My App", "sku": "MYAPP", "state": "READY" },
              "relationships": { "builds": { "links": {} } } }
          ],
          "included": [
            { "type": "build", "id": "1" }, { "type": "build", "id": "2" },
            { "type": "build", "id": "3" }, { "type": "build", "id": "4" }
          ]
        }
        """
        let parsed = try XCTUnwrap(ParsedOutput.parse(json))
        // `data` must win even though `included` is the larger array.
        XCTAssertEqual(parsed.collection, "data")
        XCTAssertEqual(parsed.records.count, 1)

        let record = parsed.records[0]
        // attributes were flattened up so name/state are first-class.
        XCTAssertEqual(record.title, "My App")
        XCTAssertEqual(record.badge, "READY")
        // structural noise must not leak into displayed fields.
        let labels = record.fields.map(\.label)
        XCTAssertFalse(labels.contains { $0.lowercased().contains("relationship") })
    }

    func testSingleObjectBecomesOneRecord() throws {
        let json = #"{ "name": "Solo", "state": "ACTIVE" }"#
        let parsed = try XCTUnwrap(ParsedOutput.parse(json))
        XCTAssertEqual(parsed.records.count, 1)
        XCTAssertEqual(parsed.records[0].title, "Solo")
    }
}
