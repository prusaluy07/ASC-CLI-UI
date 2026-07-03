import Foundation

/// Plans which search terms should be tracked in Appfigures.
///
/// The public Appfigures API v2 is read-only for ASO keywords (`GET /aso`,
/// `GET /aso/stats`) — there is no endpoint to create tracked keywords. So the
/// tracking agent works as a closed loop instead: it *plans* the list (this type),
/// exports it for Appfigures' bulk-add box, and afterwards *verifies* via
/// `GET /aso` which of the planned terms are actually being tracked.
///
/// Unlike the keyword-field packer (single deduped words), tracking wants whole
/// **search phrases** — "habit tracker" ranks differently than "habit" + "tracker".
public struct KeywordTrackingPlan: Sendable, Equatable {
    /// Terms worth tracking that are not tracked yet, best first.
    public let suggestions: [String]
    /// Suggested terms that Appfigures already tracks (kept for transparency).
    public let alreadyTracked: [String]

    public init(suggestions: [String], alreadyTracked: [String]) {
        self.suggestions = suggestions
        self.alreadyTracked = alreadyTracked
    }

    // MARK: Building

    /// Combines ASO candidates (phrases preserved), the app's name/subtitle phrases,
    /// and frequent review bigrams into a tracking list, minus what's already tracked.
    public static func build(input: ASOInput,
                             candidates: [ASOCandidate],
                             limit: Int = 50) -> KeywordTrackingPlan {
        let trackedTerms = Set(input.tracked.map { ASOAgentEngine.normalize($0.term) })

        var ordered: [String] = []
        var seen: Set<String> = []
        func add(_ term: String) {
            let normalized = ASOAgentEngine.normalize(term)
            guard !normalized.isEmpty, !seen.contains(normalized) else { return }
            // Single reserved words ("app", "free") are pointless to track;
            // phrases containing them ("free voice recorder") stay in.
            if !normalized.contains(" "),
               ASOAgentEngine.reservedWords.contains(normalized) { return }
            guard normalized.count >= 2 else { return }
            seen.insert(normalized)
            ordered.append(normalized)
        }

        // 1 — scored candidates (already sorted best-first by the engine).
        for candidate in candidates { add(candidate.term) }
        // 2 — the app's own name/subtitle as phrases (how users actually search).
        add(input.appName)
        if let subtitle = input.subtitle { add(subtitle) }
        // 3 — how reviewers phrase things, as two-word search phrases.
        for (bigram, _) in mineBigrams(input.reviewTexts, language: input.languageCode) {
            add(bigram)
        }

        var suggestions: [String] = []
        var already: [String] = []
        for term in ordered {
            if trackedTerms.contains(term) {
                already.append(term)
            } else if suggestions.count < limit {
                suggestions.append(term)
            }
        }
        return KeywordTrackingPlan(suggestions: suggestions, alreadyTracked: already)
    }

    /// Frequent adjacent word pairs from review texts (both words meaningful),
    /// sorted by frequency then alphabetically. Deterministic.
    public static func mineBigrams(_ texts: [String], language: String,
                                   minCount: Int = 2) -> [(term: String, count: Int)] {
        guard !texts.isEmpty else { return [] }
        let stops = (ASOAgentEngine.stopwords[language] ?? [])
            .union(ASOAgentEngine.stopwords["en"] ?? [])
            .union(ASOAgentEngine.stopwords["de"] ?? [])
        var freq: [String: Int] = [:]
        for text in texts {
            // Sentence-ish segments so bigrams don't span punctuation.
            for segment in text.lowercased().split(whereSeparator: { ".,!?;:()\n".contains($0) }) {
                let words = segment
                    .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
                    .map(String.init)
                guard words.count >= 2 else { continue }
                for i in 0..<(words.count - 1) {
                    let a = words[i], b = words[i + 1]
                    guard a.count > 2, b.count > 2,
                          !stops.contains(a), !stops.contains(b),
                          !ASOAgentEngine.reservedWords.contains(a),
                          !ASOAgentEngine.reservedWords.contains(b) else { continue }
                    freq["\(a) \(b)", default: 0] += 1
                }
            }
        }
        return freq
            .filter { $0.value >= minCount }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map { (term: $0.key, count: $0.value) }
    }

    // MARK: Export & verification

    /// One term per line — the format Appfigures' bulk-add box accepts.
    public static func exportText(_ terms: [String]) -> String {
        terms.joined(separator: "\n")
    }

    /// After the user pasted the list into Appfigures, diff the planned terms
    /// against a fresh `GET /aso` result.
    public static func verify(planned: [String],
                              tracked: [AppfiguresKeyword]) -> (tracked: [String], missing: [String]) {
        let trackedSet = Set(tracked.map { ASOAgentEngine.normalize($0.term) })
        var found: [String] = []
        var missing: [String] = []
        for term in planned {
            let normalized = ASOAgentEngine.normalize(term)
            if trackedSet.contains(normalized) {
                found.append(normalized)
            } else {
                missing.append(normalized)
            }
        }
        return (found, missing)
    }
}
