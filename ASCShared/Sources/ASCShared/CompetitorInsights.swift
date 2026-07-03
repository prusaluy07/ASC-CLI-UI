import Foundation

/// A term mined from competitor app names, with the number of distinct
/// competitor apps whose store title contains it.
public struct CompetitorTerm: Sendable, Equatable {
    public let term: String
    public let appCount: Int

    public init(term: String, appCount: Int) {
        self.term = term
        self.appCount = appCount
    }
}

/// Mines keyword material from competitor App Store titles (iTunes Search results).
/// Competitor titles are deliberate keyword placements — words several competitors
/// carry in their title are proven search demand.
public enum CompetitorMiner {
    /// Separators app titles use between brand and keyword phrases
    /// ("Foo – Habit Tracker & Journal", "Bar: Sleep Sounds | Relax").
    private static let phraseSeparators: Set<Character> = ["-", "–", "—", ":", "|", ",", "&", "·", "("]

    /// Extracts terms from the given search results, skipping the app itself.
    /// Single words must appear in ≥ 2 apps; keyword phrases (2–3 words, taken from
    /// the segments *after* the brand name) count from a single occurrence.
    /// Deterministic: sorted by app count, then alphabetically.
    public static func mine(_ apps: [ITunesAppResult],
                            excludingTrackId: Int64? = nil,
                            excludingBundleId: String? = nil,
                            language: String = "en",
                            limit: Int = 30) -> [CompetitorTerm] {
        let stops = (ASOAgentEngine.stopwords[language] ?? [])
            .union(ASOAgentEngine.stopwords["en"] ?? [])
            .union(ASOAgentEngine.stopwords["de"] ?? [])

        var counts: [String: Int] = [:]
        for app in apps {
            if let excludingTrackId, app.trackId == excludingTrackId { continue }
            if let excludingBundleId, let bundle = app.bundleId,
               bundle.caseInsensitiveCompare(excludingBundleId) == .orderedSame { continue }

            var appTerms: Set<String> = []
            let segments = app.trackName.split(whereSeparator: { phraseSeparators.contains($0) })
            // The first segment is usually the brand; the rest is keyword copy.
            for segment in segments.dropFirst() {
                let phrase = ASOAgentEngine.normalize(String(segment))
                let wordCount = phrase.split(separator: " ").count
                if (2...3).contains(wordCount) { appTerms.insert(phrase) }
            }
            // Individual words from all segments except the brand words themselves.
            let brandWords = segments.first.map { ASOAgentEngine.words(in: String($0)) } ?? []
            for segment in segments.dropFirst() {
                for word in ASOAgentEngine.wordList(in: String(segment))
                where word.count > 2 && !stops.contains(word)
                      && !ASOAgentEngine.reservedWords.contains(word)
                      && !brandWords.contains(word) {
                    appTerms.insert(word)
                }
            }
            for term in appTerms { counts[term, default: 0] += 1 }
        }

        return counts
            .filter { term, count in
                term.contains(" ") ? count >= 1 : count >= 2
            }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(limit)
            .map { CompetitorTerm(term: $0.key, appCount: $0.value) }
    }
}
