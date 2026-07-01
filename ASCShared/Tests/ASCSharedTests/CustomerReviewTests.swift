import XCTest
@testable import ASCShared

final class CustomerReviewTests: XCTestCase {
    func testParsesJSONAPIReviews() {
        let json = """
        {"data":[{"id":"rev1","type":"customerReviews","attributes":{"rating":5,"title":"Great","body":"Love it","territory":"USA","createdDate":"2026-06-01T10:00:00Z","reviewerNickname":"User1"}}]}
        """
        let reviews = CustomerReviewParser.parse(json)
        XCTAssertEqual(reviews.count, 1)
        XCTAssertEqual(reviews[0].id, "rev1")
        XCTAssertEqual(reviews[0].rating, 5)
        XCTAssertEqual(reviews[0].title, "Great")
    }
}
