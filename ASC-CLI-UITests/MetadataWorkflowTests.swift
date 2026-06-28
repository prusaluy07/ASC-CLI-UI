import XCTest
@testable import ASC_CLI_UI

@MainActor
final class MetadataWorkflowTests: XCTestCase {

    private func sampleInput() -> AgentBriefInput {
        AgentBriefInput(
            appName: "Sereno", bundleId: "com.x.sereno", appId: "123",
            versionString: "1.2.3",
            goal: "Calm focus app", audience: "Students", tone: "Warm",
            principles: "No hype", locales: ["en-US", "de-DE"], includeCurrent: true,
            current: ["en-US": ["description": "Old desc", "keywords": "calm,focus"]]
        )
    }

    func testMarkdownIncludesLimitsAndApplyCommand() {
        let md = AgentBriefBuilder.markdown(sampleInput())
        XCTAssertTrue(md.contains("4000"))           // description limit
        XCTAssertTrue(md.contains("`keywords`"))
        XCTAssertTrue(md.contains("asc metadata apply --app 123"))
        XCTAssertTrue(md.contains("--version 1.2.3"))
        XCTAssertTrue(md.contains("en-US"))
        XCTAssertTrue(md.contains("de-DE"))
    }

    func testPlanJSONIsValidAndCarriesCurrentSnapshot() throws {
        let json = AgentBriefBuilder.planJSON(sampleInput())
        let data = try XCTUnwrap(json.data(using: .utf8))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let root = try XCTUnwrap(obj)
        XCTAssertEqual((root["app"] as? [String: Any])?["appId"] as? String, "123")

        let locales = try XCTUnwrap(root["locales"] as? [[String: Any]])
        XCTAssertEqual(locales.count, 2)
        let en = try XCTUnwrap(locales.first { $0["locale"] as? String == "en-US" })
        let current = try XCTUnwrap(en["current"] as? [String: Any])
        XCTAssertEqual(current["description"] as? String, "Old desc")
        // proposed skeleton has every field key.
        let proposed = try XCTUnwrap(en["proposed"] as? [String: Any])
        XCTAssertNotNil(proposed["description"])
        XCTAssertNotNil(proposed["keywords"])
    }

    func testPlanJSONOmitsCurrentWhenDisabled() throws {
        var input = sampleInput()
        input.includeCurrent = false
        let json = AgentBriefBuilder.planJSON(input)
        let data = try XCTUnwrap(json.data(using: .utf8))
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let locales = try XCTUnwrap(root["locales"] as? [[String: Any]])
        XCTAssertNil(locales.first?["current"])
    }

    func testFieldSpecsCoverCoreAppStoreFields() {
        let keys = Set(MetadataPlan.fields.map(\.key))
        XCTAssertTrue(keys.isSuperset(of: ["name", "subtitle", "description", "keywords", "whatsNew", "promotionalText"]))
    }
}
