import XCTest
import ASCShared

final class CompetitorScorecardTests: XCTestCase {

    private func app(_ id: Int64, _ name: String, bundleId: String? = nil) -> ITunesAppResult {
        ITunesAppResult(trackId: id, trackName: name, artistName: "Dev", bundleId: bundleId)
    }

    // MARK: - Competitor mining

    func testMinesWordsUsedByMultipleCompetitors() {
        let apps = [
            app(1, "Notely – Voice Recorder & Notes"),
            app(2, "Recordo: Voice Recorder"),
            app(3, "Tape - Audio Memos")
        ]
        let terms = CompetitorMiner.mine(apps, language: "en")
        // "recorder" and "voice" appear in 2 apps; "audio"/"memos" only in 1 (single words need ≥2).
        let byTerm = Dictionary(uniqueKeysWithValues: terms.map { ($0.term, $0.appCount) })
        XCTAssertEqual(byTerm["recorder"], 2)
        XCTAssertEqual(byTerm["voice"], 2)
        XCTAssertNil(byTerm["audio"])
        // Phrases from the keyword part of a title count from one occurrence.
        XCTAssertEqual(byTerm["voice recorder"], 2)
        XCTAssertEqual(byTerm["audio memos"], 1)
    }

    func testBrandSegmentIsNotMined() {
        let apps = [
            app(1, "Notely – Notes"),
            app(2, "Notely Pro – Notes")
        ]
        let terms = CompetitorMiner.mine(apps, language: "en").map(\.term)
        XCTAssertFalse(terms.contains("notely"))
        XCTAssertTrue(terms.contains("notes"))
    }

    func testOwnAppIsExcluded() {
        let apps = [
            app(1, "Mine – Voice Recorder", bundleId: "de.me.mine"),
            app(2, "Other – Voice Recorder"),
            app(3, "Third – Voice Recorder")
        ]
        let withOwn = CompetitorMiner.mine(apps, language: "en")
        let withoutOwn = CompetitorMiner.mine(apps, excludingBundleId: "de.me.mine", language: "en")
        func count(_ terms: [CompetitorTerm], _ t: String) -> Int? {
            terms.first { $0.term == t }?.appCount
        }
        XCTAssertEqual(count(withOwn, "recorder"), 3)
        XCTAssertEqual(count(withoutOwn, "recorder"), 2)
    }

    func testMiningIsDeterministic() {
        let apps = [
            app(1, "A – Alpha Beta"),
            app(2, "B – Beta Gamma"),
            app(3, "C – Gamma Alpha")
        ]
        let first = CompetitorMiner.mine(apps, language: "en").map(\.term)
        for _ in 0..<5 {
            XCTAssertEqual(CompetitorMiner.mine(apps, language: "en").map(\.term), first)
        }
    }

    // MARK: - Competitor terms in the engine

    func testCompetitorAdoptionBoostsScore() {
        let input = ASOInput(
            appName: "X",
            tracked: [
                AppfiguresKeyword(term: "adopted", popularity: 40, competitiveness: 50),
                AppfiguresKeyword(term: "plain", popularity: 40, competitiveness: 50)
            ],
            competitorTerms: ["adopted": 4]
        )
        let candidates = ASOAgentEngine.propose(input).candidates
        let byTerm = Dictionary(uniqueKeysWithValues: candidates.map { ($0.term, $0) })
        XCTAssertGreaterThan(byTerm["adopted"]!.score, byTerm["plain"]!.score)
        XCTAssertTrue(byTerm["adopted"]!.sources.contains(.competitor))
    }

    func testCompetitorOnlyTermsBecomeCandidates() {
        let input = ASOInput(appName: "X", competitorTerms: ["sleep sounds": 3])
        let candidates = ASOAgentEngine.propose(input).candidates
        XCTAssertTrue(candidates.contains { $0.term == "sleep sounds" && $0.sources == [.competitor] })
    }

    // MARK: - Scorecard

    func testPerfectMetadataScoresFull() {
        // 25 unique 3-char words joined by commas = 99/100 chars (rounds to full points).
        let field = (1...25).map { String(format: "k%02d", $0) }.joined(separator: ",")
        let input = ASOInput(
            appName: String(repeating: "a", count: 30),
            subtitle: String(repeating: "b", count: 30),
            currentKeywords: field
        )
        let proposal = ASOAgentEngine.propose(input)
        let scorecard = ASOScorecard.evaluate(input: input, warnings: proposal.warnings)
        XCTAssertEqual(scorecard.total, scorecard.maxTotal)
        XCTAssertEqual(scorecard.maxTotal, 100)
    }

    func testEmptyMetadataScoresLow() {
        let input = ASOInput(appName: "Ab")
        let scorecard = ASOScorecard.evaluate(input: input, warnings: [])
        let byKind = Dictionary(uniqueKeysWithValues: scorecard.items.map { ($0.kind, $0) })
        XCTAssertEqual(byKind[.keywordBudget]?.points, 0)
        XCTAssertEqual(byKind[.subtitleUsage]?.points, 0)
        XCTAssertEqual(byKind[.cleanliness]?.points, 30)   // nothing there, nothing wasted
        XCTAssertEqual(byKind[.titleUsage]?.points, 1)     // 2/30 of 20 rounds to 1
    }

    func testFindingsReduceCleanliness() {
        let input = ASOInput(
            appName: "Habit Hero",
            currentKeywords: "habit, tracker, tracker, free"   // 4 finding kinds
        )
        let proposal = ASOAgentEngine.propose(input)
        let scorecard = ASOScorecard.evaluate(input: input, warnings: proposal.warnings)
        let cleanliness = scorecard.items.first { $0.kind == .cleanliness }
        XCTAssertEqual(cleanliness?.points, 0)   // 30 − 4×8, floored at 0
    }

    func testUnusedBudgetDoesNotAffectCleanliness() {
        let scorecard = ASOScorecard.evaluate(
            input: ASOInput(appName: "X", currentKeywords: "one,two"),
            warnings: [.unusedBudget(remaining: 90)]
        )
        XCTAssertEqual(scorecard.items.first { $0.kind == .cleanliness }?.points, 30)
    }
}
