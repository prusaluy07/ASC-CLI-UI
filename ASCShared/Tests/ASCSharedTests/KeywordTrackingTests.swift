import XCTest
import ASCShared

final class KeywordTrackingTests: XCTestCase {

    private func plan(input: ASOInput, limit: Int = 50) -> KeywordTrackingPlan {
        KeywordTrackingPlan.build(input: input,
                                  candidates: ASOAgentEngine.propose(input).candidates,
                                  limit: limit)
    }

    // MARK: - Building

    func testPlanKeepsPhrasesAndExcludesTracked() {
        let input = ASOInput(
            appName: "Voicement",
            seedKeywords: ["voice recorder", "meeting notes"],
            tracked: [AppfiguresKeyword(term: "Voice Recorder", popularity: 60, competitiveness: 30)]
        )
        let result = plan(input: input)
        // Already tracked (case-insensitive) → not suggested again, but reported.
        XCTAssertFalse(result.suggestions.contains("voice recorder"))
        XCTAssertTrue(result.alreadyTracked.contains("voice recorder"))
        // Phrases survive whole — tracking wants search phrases, not word pools.
        XCTAssertTrue(result.suggestions.contains("meeting notes"))
        // The app's own name is a search phrase worth tracking.
        XCTAssertTrue(result.suggestions.contains("voicement"))
    }

    func testSeedRanksBeforeAppNamePhrase() throws {
        let input = ASOInput(appName: "Zed Tools", seedKeywords: ["strong idea"])
        let result = plan(input: input)
        let seedIndex = try XCTUnwrap(result.suggestions.firstIndex(of: "strong idea"))
        let nameIndex = try XCTUnwrap(result.suggestions.firstIndex(of: "zed tools"))
        // Scored candidates come first; the app-name phrase is appended after them.
        XCTAssertLessThan(seedIndex, nameIndex)
    }

    func testSingleReservedWordsExcludedButPhrasesKept() {
        let input = ASOInput(appName: "X", seedKeywords: ["free", "free voice recorder"])
        let result = plan(input: input)
        XCTAssertFalse(result.suggestions.contains("free"))
        XCTAssertTrue(result.suggestions.contains("free voice recorder"))
    }

    func testLimitCapsSuggestions() {
        let seeds = (1...80).map { "keyword idea \($0)" }
        let input = ASOInput(appName: "X", seedKeywords: seeds)
        let result = plan(input: input, limit: 10)
        XCTAssertEqual(result.suggestions.count, 10)
    }

    // MARK: - Bigram mining

    func testMinesFrequentReviewBigrams() {
        let texts = Array(repeating: "Der Diktier Rekorder ist perfekt.", count: 3)
        let bigrams = KeywordTrackingPlan.mineBigrams(texts, language: "de")
        XCTAssertEqual(bigrams.first?.term, "diktier rekorder")
        XCTAssertEqual(bigrams.first?.count, 3)
        // Pairs involving stopwords ("der", "ist") must not appear.
        XCTAssertFalse(bigrams.contains { $0.term.hasPrefix("der ") || $0.term.hasSuffix(" ist") })
    }

    func testBigramsDoNotSpanSentences() {
        let texts = Array(repeating: "Great recorder. Amazing quality.", count: 3)
        let bigrams = KeywordTrackingPlan.mineBigrams(texts, language: "en")
        // "recorder amazing" spans the period → must not appear.
        XCTAssertFalse(bigrams.contains { $0.term == "recorder amazing" })
        XCTAssertTrue(bigrams.contains { $0.term == "amazing quality" })
    }

    func testBigramMiningIsDeterministic() {
        let texts = [
            "voice memo voice memo",
            "quick notes quick notes",
            "voice memo quick notes"
        ]
        let first = KeywordTrackingPlan.mineBigrams(texts, language: "en").map(\.term)
        for _ in 0..<5 {
            XCTAssertEqual(KeywordTrackingPlan.mineBigrams(texts, language: "en").map(\.term), first)
        }
    }

    func testPlanIncludesReviewBigrams() {
        let texts = Array(repeating: "Perfekter Diktier Rekorder für unterwegs.", count: 3)
        let input = ASOInput(appName: "X", reviewTexts: texts, languageCode: "de")
        let result = plan(input: input)
        XCTAssertTrue(result.suggestions.contains("diktier rekorder"))
    }

    // MARK: - Export & verify

    func testExportIsOneTermPerLine() {
        XCTAssertEqual(KeywordTrackingPlan.exportText(["a b", "c"]), "a b\nc")
        XCTAssertEqual(KeywordTrackingPlan.exportText([]), "")
    }

    func testVerifyPartitionsPlannedTerms() {
        let tracked = [
            AppfiguresKeyword(term: "Habit Tracker"),
            AppfiguresKeyword(term: "journal")
        ]
        let result = KeywordTrackingPlan.verify(planned: ["habit tracker", "journal", "planner"],
                                                tracked: tracked)
        XCTAssertEqual(result.tracked, ["habit tracker", "journal"])
        XCTAssertEqual(result.missing, ["planner"])
    }
}
