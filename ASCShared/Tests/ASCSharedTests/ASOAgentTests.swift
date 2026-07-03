import XCTest
import ASCShared

final class ASOAgentTests: XCTestCase {

    // MARK: - Appfigures parsing

    func testParsesProductMap() throws {
        let json = """
        {
          "411507712": { "id": 411507712, "name": "Voicement", "developer": "Acme",
                         "ref_no": "6776550237", "store": "apple",
                         "bundle_identifier": "de.acme.voicement" },
          "411507713": { "id": 411507713, "name": "Other", "ref_no": "123", "store": "apple" }
        }
        """
        let products = AppfiguresClient.parseProducts(Data(json.utf8))
        XCTAssertEqual(products.count, 2)
        let first = try XCTUnwrap(products.first)
        XCTAssertEqual(first.id, 411507712)
        XCTAssertEqual(first.refNo, "6776550237")
        XCTAssertEqual(first.bundleId, "de.acme.voicement")
    }

    func testParsesProductArrayAndNumericRefNo() throws {
        let json = #"[ { "id": 5, "name": "X", "ref_no": 6776550237 } ]"#
        let products = AppfiguresClient.parseProducts(Data(json.utf8))
        XCTAssertEqual(products.first?.refNo, "6776550237")
    }

    func testParseProductsGarbage() {
        XCTAssertTrue(AppfiguresClient.parseProducts(Data("not json".utf8)).isEmpty)
        XCTAssertTrue(AppfiguresClient.parseProducts(Data("42".utf8)).isEmpty)
    }

    func testParsesKeywordsPageWithMetadata() throws {
        let json = """
        {
          "metadata": { "page": 1, "pages": 2 },
          "results": [
            { "keyword_term": "habit tracker", "position": 4, "delta": -2,
              "popularity": 62, "competitiveness": 41, "num_apps": 220 },
            { "keyword": { "term": "journal" }, "position": 0, "popularity": 80, "competitiveness": 90 }
          ]
        }
        """
        let page = AppfiguresClient.parseKeywordsPage(Data(json.utf8))
        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.keywords.count, 2)
        XCTAssertEqual(page.keywords[0].term, "habit tracker")
        XCTAssertEqual(page.keywords[0].position, 4)
        // Position 0 means "not ranked" and must become nil.
        XCTAssertNil(page.keywords[1].position)
        XCTAssertEqual(page.keywords[1].term, "journal")
    }

    func testParseKeywordsLastPage() {
        let json = #"{ "metadata": { "page": 2, "pages": 2 }, "results": [] }"#
        let page = AppfiguresClient.parseKeywordsPage(Data(json.utf8))
        XCTAssertFalse(page.hasMore)
        XCTAssertTrue(page.keywords.isEmpty)
    }

    // MARK: - Scoring & ordering

    func testPopularLowCompetitionTermScoresHighest() {
        let input = ASOInput(
            appName: "Voicement",
            tracked: [
                AppfiguresKeyword(term: "easy win", popularity: 70, competitiveness: 20),
                AppfiguresKeyword(term: "crowded", popularity: 70, competitiveness: 95),
                AppfiguresKeyword(term: "obscure", popularity: 5, competitiveness: 5)
            ]
        )
        let proposal = ASOAgentEngine.propose(input)
        XCTAssertEqual(proposal.candidates.first?.term, "easy win")
        let crowded = proposal.candidates.first { $0.term == "crowded" }
        let easy = proposal.candidates.first { $0.term == "easy win" }
        XCTAssertGreaterThan(easy!.score, crowded!.score)
    }

    func testSeedAndRankBoosts() {
        let input = ASOInput(
            appName: "X",
            seedKeywords: ["boosted"],
            tracked: [
                AppfiguresKeyword(term: "boosted", popularity: 40, competitiveness: 50),
                AppfiguresKeyword(term: "plain", popularity: 40, competitiveness: 50),
                AppfiguresKeyword(term: "ranking", position: 3, popularity: 40, competitiveness: 50)
            ]
        )
        let byTerm = Dictionary(uniqueKeysWithValues: ASOAgentEngine.propose(input).candidates.map { ($0.term, $0.score) })
        XCTAssertGreaterThan(byTerm["boosted"]!, byTerm["plain"]!)
        XCTAssertGreaterThan(byTerm["ranking"]!, byTerm["plain"]!)
    }

    // MARK: - Keyword field packing

    func testKeywordFieldRespectsLimitAndDedupes() {
        let input = ASOInput(
            appName: "Habit Hero",
            subtitle: "Daily Tracker",
            currentKeywords: "habit, tracker,goals",
            seedKeywords: ["goal setting", "routine planner", "habit tracker"],
            tracked: [],
            keywordLimit: 30
        )
        let field = ASOAgentEngine.propose(input).keywordField
        XCTAssertLessThanOrEqual(field.count, 30)
        XCTAssertFalse(field.contains(" "))
        let words = field.split(separator: ",").map(String.init)
        XCTAssertEqual(Set(words).count, words.count, "no duplicate words")
        // "habit" (name) and "tracker"/"daily" (subtitle) are already indexed by Apple.
        XCTAssertFalse(words.contains("habit"))
        XCTAssertFalse(words.contains("tracker"))
        XCTAssertFalse(words.contains("daily"))
    }

    func testKeywordFieldExcludesReservedWords() {
        let input = ASOInput(appName: "X", seedKeywords: ["free app download", "recorder"])
        let words = ASOAgentEngine.propose(input).keywordField.split(separator: ",").map(String.init)
        XCTAssertFalse(words.contains("free"))
        XCTAssertFalse(words.contains("app"))
        XCTAssertTrue(words.contains("recorder"))
        XCTAssertTrue(words.contains("download"))
    }

    func testPackingIsDeterministic() {
        let input = ASOInput(
            appName: "X",
            seedKeywords: ["alpha beta", "gamma delta epsilon", "zeta"],
            keywordLimit: 25
        )
        let first = ASOAgentEngine.propose(input).keywordField
        for _ in 0..<10 {
            XCTAssertEqual(ASOAgentEngine.propose(input).keywordField, first)
        }
    }

    func testUmlautsSurviveNormalization() {
        let input = ASOInput(appName: "X", seedKeywords: ["Ernährung", "Küchen Planer"])
        let field = ASOAgentEngine.propose(input).keywordField
        XCTAssertTrue(field.contains("ernährung"))
        XCTAssertTrue(field.contains("küchen"))
    }

    // MARK: - Current-field warnings

    func testWarningsOnSloppyCurrentField() {
        let input = ASOInput(
            appName: "Habit Hero",
            currentKeywords: "habit, tracker, tracker, free",
            seedKeywords: ["x"]
        )
        let warnings = ASOAgentEngine.propose(input).warnings
        XCTAssertTrue(warnings.contains { if case .spacesAfterCommas(let n) = $0 { return n == 3 } else { return false } })
        XCTAssertTrue(warnings.contains { if case .duplicateWords(let w) = $0 { return w == ["tracker"] } else { return false } })
        XCTAssertTrue(warnings.contains { if case .titleDuplicates(let w) = $0 { return w == ["habit"] } else { return false } })
        XCTAssertTrue(warnings.contains { if case .reservedWords(let w) = $0 { return w == ["free"] } else { return false } })
    }

    func testOverLimitWarning() {
        let long = String(repeating: "abcdefgh,", count: 14)   // 126 chars
        let input = ASOInput(appName: "X", currentKeywords: long)
        let warnings = ASOAgentEngine.propose(input).warnings
        XCTAssertTrue(warnings.contains { if case .overLimit(let current, let max) = $0 { return current == long.count && max == 100 } else { return false } })
    }

    func testCleanCurrentFieldProducesNoFieldWarnings() {
        let input = ASOInput(
            appName: "Voicement",
            currentKeywords: "recorder,transcript,notes",
            tracked: [AppfiguresKeyword(term: "voice memo", popularity: 60, competitiveness: 30)]
        )
        let warnings = ASOAgentEngine.propose(input).warnings
        for warning in warnings {
            if case .unusedBudget = warning { continue }
            XCTFail("unexpected warning: \(warning)")
        }
    }

    // MARK: - Title / subtitle suggestions

    func testSuggestionsRespectCharacterLimits() {
        let input = ASOInput(
            appName: "Voicement",
            tracked: [
                AppfiguresKeyword(term: "voice recorder", popularity: 70, competitiveness: 30),
                AppfiguresKeyword(term: "transcription", popularity: 60, competitiveness: 30)
            ]
        )
        let proposal = ASOAgentEngine.propose(input)
        for title in proposal.titleSuggestions {
            XCTAssertLessThanOrEqual(title.count, ASOAgentEngine.nameLimit)
            XCTAssertTrue(title.hasPrefix("Voicement"))
        }
        for subtitle in proposal.subtitleSuggestions {
            XCTAssertLessThanOrEqual(subtitle.count, ASOAgentEngine.subtitleLimit)
        }
        XCTAssertFalse(proposal.subtitleSuggestions.isEmpty)
    }

    // MARK: - Review mining

    func testReviewMiningSurfacesFrequentWords() {
        let review = "Perfekt zum Meditieren. Nutze die Meditation jeden Tag beim Meditieren."
        let input = ASOInput(
            appName: "X",
            reviewTexts: [review, "Meditieren hilft mir sehr.", "meditieren ist toll"],
            languageCode: "de"
        )
        let proposal = ASOAgentEngine.propose(input)
        let mined = proposal.candidates.first { $0.term == "meditieren" }
        XCTAssertNotNil(mined)
        XCTAssertTrue(mined!.sources.contains(.reviews))
    }

    func testStopwordsAndShortWordsNotMined() {
        let texts = Array(repeating: "sehr sehr toll toll die die und und app app", count: 5)
        let input = ASOInput(appName: "X", reviewTexts: texts, languageCode: "de")
        let terms = Set(ASOAgentEngine.propose(input).candidates.map(\.term))
        XCTAssertFalse(terms.contains("sehr"))
        XCTAssertFalse(terms.contains("die"))
        XCTAssertFalse(terms.contains("app"))
    }

    // MARK: - Report

    func testReportContainsProposalAndCandidates() {
        let input = ASOInput(
            appName: "Voicement",
            currentKeywords: "old,words",
            tracked: [AppfiguresKeyword(term: "voice recorder", position: 7,
                                        popularity: 70, competitiveness: 30)]
        )
        let proposal = ASOAgentEngine.propose(input)
        let report = ASOResearchReport.markdown(appName: "Voicement", country: "de",
                                                input: input, proposal: proposal)
        XCTAssertTrue(report.contains("# ASO research — Voicement (DE)"))
        XCTAssertTrue(report.contains(proposal.keywordField))
        XCTAssertTrue(report.contains("| voice recorder |"))
        XCTAssertTrue(report.contains("old,words"))
    }
}
