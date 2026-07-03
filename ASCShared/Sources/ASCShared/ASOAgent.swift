import Foundation

// MARK: - Input

/// Everything the ASO agent needs to compose a proposal. Pure value type so the
/// whole pipeline is unit-testable without asc, Appfigures, or a network.
public struct ASOInput: Sendable {
    public var appName: String
    public var subtitle: String?
    /// The current App Store keyword field (comma-separated).
    public var currentKeywords: String?
    /// User-provided keyword ideas.
    public var seedKeywords: [String]
    /// Tracked keyword ranks from Appfigures (may be empty).
    public var tracked: [AppfiguresKeyword]
    /// Customer review titles/bodies to mine for wording (may be empty).
    public var reviewTexts: [String]
    /// Terms mined from competitor titles → number of competitor apps using them.
    public var competitorTerms: [String: Int]
    /// "de", "en", … — controls the stopword list used for review mining.
    public var languageCode: String
    public var keywordLimit: Int

    public init(appName: String,
                subtitle: String? = nil,
                currentKeywords: String? = nil,
                seedKeywords: [String] = [],
                tracked: [AppfiguresKeyword] = [],
                reviewTexts: [String] = [],
                competitorTerms: [String: Int] = [:],
                languageCode: String = "en",
                keywordLimit: Int = 100) {
        self.appName = appName
        self.subtitle = subtitle
        self.currentKeywords = currentKeywords
        self.seedKeywords = seedKeywords
        self.tracked = tracked
        self.reviewTexts = reviewTexts
        self.competitorTerms = competitorTerms
        self.languageCode = languageCode
        self.keywordLimit = keywordLimit
    }
}

// MARK: - Output

/// A scored keyword candidate with the evidence behind its score.
public struct ASOCandidate: Sendable, Identifiable, Hashable {
    public enum Source: String, Sendable, CaseIterable {
        case tracked, seed, current, reviews, competitor
    }

    public let term: String
    public let score: Double
    public let sources: Set<Source>
    public let popularity: Double?
    public let competitiveness: Double?
    public let position: Int?
    /// True when every word of the term already appears in the app name or subtitle —
    /// Apple indexes those fields, so repeating the words in `keywords` wastes characters.
    public let coveredByTitle: Bool

    public var id: String { term }
}

/// Machine-checkable findings about the *current* metadata; the UI localizes them.
public enum ASOWarning: Sendable, Equatable {
    /// Spaces after commas in the keyword field waste characters.
    case spacesAfterCommas(count: Int)
    /// The same word appears multiple times in the keyword field.
    case duplicateWords([String])
    /// Keyword-field words that already appear in the app name or subtitle.
    case titleDuplicates([String])
    /// The current keyword field exceeds the limit (ASC would reject it).
    case overLimit(current: Int, max: Int)
    /// Terms Apple tells developers not to spend keyword characters on.
    case reservedWords([String])
    /// The proposed field leaves this many characters unused (not enough candidates).
    case unusedBudget(remaining: Int)
}

public struct ASOProposal: Sendable {
    /// All candidates, best first.
    public let candidates: [ASOCandidate]
    /// Optimized keyword field: single words, comma-separated, no spaces, ≤ limit.
    public let keywordField: String
    /// App-name ideas that fit the 30-character cap (empty when nothing beats the current name).
    public let titleSuggestions: [String]
    /// Subtitle ideas that fit the 30-character cap.
    public let subtitleSuggestions: [String]
    public let warnings: [ASOWarning]
}

// MARK: - Engine

public enum ASOAgentEngine {
    public static let nameLimit = 30
    public static let subtitleLimit = 30

    /// Words Apple explicitly ignores or rejects in the keyword field.
    static let reservedWords: Set<String> = ["app", "apps", "free", "kostenlos", "gratis", "iphone", "ipad", "ios"]

    static let stopwords: [String: Set<String>] = [
        "en": ["the", "a", "an", "and", "or", "for", "with", "your", "you", "to", "of", "in",
               "on", "is", "it", "at", "by", "my", "me", "this", "that", "very", "not", "but",
               "have", "has", "was", "are", "be", "can", "all", "so", "just", "great", "good",
               "love", "like", "really", "use", "using", "get", "i"],
        "de": ["der", "die", "das", "und", "oder", "für", "mit", "dein", "deine", "du", "zu",
               "von", "im", "am", "auf", "ist", "es", "ein", "eine", "einen", "sehr", "nicht",
               "aber", "habe", "hat", "war", "sind", "sein", "kann", "alle", "so", "nur",
               "super", "toll", "gut", "gerne", "man", "ich", "auch", "mal", "wie", "bei"]
    ]

    // MARK: Pipeline

    public static func propose(_ input: ASOInput) -> ASOProposal {
        let titleWords = words(in: input.appName).union(words(in: input.subtitle ?? ""))
        let candidates = buildCandidates(input, titleWords: titleWords)
        let field = packKeywordField(candidates, titleWords: titleWords, limit: input.keywordLimit)
        let warnings = analyzeCurrent(input, titleWords: titleWords)
            + budgetWarnings(field: field, limit: input.keywordLimit, candidates: candidates)
        return ASOProposal(
            candidates: candidates,
            keywordField: field,
            titleSuggestions: titleSuggestions(input, candidates: candidates),
            subtitleSuggestions: subtitleSuggestions(input, candidates: candidates),
            warnings: warnings
        )
    }

    // MARK: Candidates

    private static func buildCandidates(_ input: ASOInput, titleWords: Set<String>) -> [ASOCandidate] {
        struct Accumulator {
            var sources: Set<ASOCandidate.Source> = []
            var popularity: Double?
            var competitiveness: Double?
            var position: Int?
            var reviewHits = 0
            var competitorHits = 0
        }
        var acc: [String: Accumulator] = [:]
        var order: [String] = []   // stable order for equal scores

        func slot(_ term: String) -> String {
            let key = normalize(term)
            if acc[key] == nil { acc[key] = Accumulator(); order.append(key) }
            return key
        }

        for keyword in input.tracked {
            let key = slot(keyword.term)
            acc[key]?.sources.insert(.tracked)
            acc[key]?.popularity = keyword.popularity
            acc[key]?.competitiveness = keyword.competitiveness
            acc[key]?.position = keyword.position
        }
        for seed in input.seedKeywords where !normalize(seed).isEmpty {
            acc[slot(seed)]?.sources.insert(.seed)
        }
        for term in splitKeywordField(input.currentKeywords ?? "") {
            acc[slot(term)]?.sources.insert(.current)
        }
        for (term, count) in input.competitorTerms.sorted(by: { $0.key < $1.key }) {
            let key = slot(term)
            acc[key]?.sources.insert(.competitor)
            acc[key]?.competitorHits = max(acc[key]?.competitorHits ?? 0, count)
        }

        // Review mining: count how often each known term (or its words) is mentioned,
        // and surface frequent unknown words as fresh candidates.
        let reviewFrequency = wordFrequencies(input.reviewTexts, language: input.languageCode)
        for (key, _) in acc {
            let hits = words(in: key).reduce(0) { $0 + (reviewFrequency[$1] ?? 0) }
            acc[key]?.reviewHits = hits
        }
        let knownWords = Set(acc.keys.flatMap { words(in: $0) })
        let minedWords = reviewFrequency.sorted {
            $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key
        }
        for (word, count) in minedWords.prefix(12)
        where count >= 3 && !knownWords.contains(word) && !titleWords.contains(word)
              && !reservedWords.contains(word) {
            let key = slot(word)
            acc[key]?.sources.insert(.reviews)
            acc[key]?.reviewHits = count
        }

        var result: [ASOCandidate] = order.compactMap { key in
            guard let a = acc[key], !key.isEmpty else { return nil }
            let covered = words(in: key).allSatisfy { titleWords.contains($0) }
            return ASOCandidate(term: key,
                                score: score(a.popularity, a.competitiveness, a.position,
                                             sources: a.sources, reviewHits: a.reviewHits,
                                             competitorHits: a.competitorHits),
                                sources: a.sources,
                                popularity: a.popularity,
                                competitiveness: a.competitiveness,
                                position: a.position,
                                coveredByTitle: covered)
        }
        result.sort { lhs, rhs in
            lhs.score != rhs.score ? lhs.score > rhs.score : lhs.term < rhs.term
        }
        return result
    }

    /// 0–100. Popular, low-competition terms win; user intent (seeds), existing good
    /// rankings, review language, and competitor adoption add smaller boosts.
    private static func score(_ popularity: Double?, _ competitiveness: Double?,
                              _ position: Int?, sources: Set<ASOCandidate.Source>,
                              reviewHits: Int, competitorHits: Int = 0) -> Double {
        let pop = popularity ?? 35            // unknown terms get a modest default
        let comp = competitiveness ?? 50
        var value = pop * (1 - 0.6 * comp / 100)
        if sources.contains(.seed) { value += 15 }
        if let position {
            if position <= 10 { value += 10 } else if position <= 50 { value += 5 }
        }
        value += min(Double(reviewHits) * 2, 10)
        // A word several competitors put in their title is proven search demand.
        value += min(Double(competitorHits) * 3, 12)
        return (value * 10).rounded() / 10
    }

    // MARK: Keyword field

    /// Apple treats the keyword field as a word pool (it combines words into phrases),
    /// so the optimal field is unique single words: comma-separated, no spaces, no words
    /// that already appear in the name/subtitle, no reserved words.
    static func packKeywordField(_ candidates: [ASOCandidate], titleWords: Set<String>, limit: Int) -> String {
        var used: Set<String> = []
        var parts: [String] = []
        var length = 0
        for candidate in candidates {
            for word in wordList(in: candidate.term) {
                guard !used.contains(word),
                      !titleWords.contains(word),
                      !reservedWords.contains(word),
                      word.count > 1 else { continue }
                let cost = word.count + (parts.isEmpty ? 0 : 1)   // +1 for the comma
                guard length + cost <= limit else { continue }
                used.insert(word)
                parts.append(word)
                length += cost
            }
        }
        return parts.joined(separator: ",")
    }

    // MARK: Title / subtitle ideas

    private static func titleSuggestions(_ input: ASOInput, candidates: [ASOCandidate]) -> [String] {
        let name = input.appName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return [] }
        var out: [String] = []
        for candidate in candidates.prefix(6) where !candidate.coveredByTitle {
            let idea = "\(name) – \(titleCase(candidate.term))"
            if idea.count <= nameLimit && !out.contains(idea) { out.append(idea) }
            if out.count == 3 { break }
        }
        return out
    }

    private static func subtitleSuggestions(_ input: ASOInput, candidates: [ASOCandidate]) -> [String] {
        let top = candidates.filter { !$0.coveredByTitle }.prefix(6).map(\.term)
        guard !top.isEmpty else { return [] }
        var out: [String] = []
        // Single strongest term, title-cased.
        if let first = top.first {
            let single = titleCase(first)
            if single.count <= subtitleLimit { out.append(single) }
        }
        // Pairs of top terms ("Habit Tracker & Journal").
        for (i, a) in top.enumerated() {
            for b in top.dropFirst(i + 1) {
                let idea = "\(titleCase(a)) & \(titleCase(b))"
                if idea.count <= subtitleLimit && !out.contains(idea) { out.append(idea) }
                if out.count >= 4 { return out }
            }
        }
        return out
    }

    // MARK: Current-state analysis

    private static func analyzeCurrent(_ input: ASOInput, titleWords: Set<String>) -> [ASOWarning] {
        var warnings: [ASOWarning] = []
        guard let current = input.currentKeywords, !current.isEmpty else { return warnings }

        let spaceyCommas = current.components(separatedBy: ", ").count - 1
        if spaceyCommas > 0 { warnings.append(.spacesAfterCommas(count: spaceyCommas)) }

        var seen: Set<String> = []
        var duplicates: [String] = []
        var inTitle: [String] = []
        var reserved: [String] = []
        for word in splitKeywordField(current).flatMap({ wordList(in: $0) }) {
            if seen.contains(word) {
                if !duplicates.contains(word) { duplicates.append(word) }
            } else {
                seen.insert(word)
            }
            if titleWords.contains(word) && !inTitle.contains(word) { inTitle.append(word) }
            if reservedWords.contains(word) && !reserved.contains(word) { reserved.append(word) }
        }
        if !duplicates.isEmpty { warnings.append(.duplicateWords(duplicates)) }
        if !inTitle.isEmpty { warnings.append(.titleDuplicates(inTitle)) }
        if !reserved.isEmpty { warnings.append(.reservedWords(reserved)) }
        if current.count > input.keywordLimit {
            warnings.append(.overLimit(current: current.count, max: input.keywordLimit))
        }
        return warnings
    }

    private static func budgetWarnings(field: String, limit: Int, candidates: [ASOCandidate]) -> [ASOWarning] {
        let remaining = limit - field.count
        // Only worth flagging when there was nothing left to add.
        guard remaining > 10, !candidates.isEmpty else { return [] }
        return [.unusedBudget(remaining: remaining)]
    }

    // MARK: Text helpers

    /// Lowercases, trims, and collapses inner whitespace ("  Habit   Tracker " → "habit tracker").
    static func normalize(_ term: String) -> String {
        term.lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    /// Letter/number word tokens of a phrase in original order, lowercased (umlauts preserved).
    static func wordList(in text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
            .map(String.init)
    }

    /// Word tokens as a set, for membership checks.
    static func words(in text: String) -> Set<String> {
        Set(wordList(in: text))
    }

    /// Splits an App Store keyword field on commas.
    static func splitKeywordField(_ field: String) -> [String] {
        field.split(separator: ",")
            .map { normalize(String($0)) }
            .filter { !$0.isEmpty }
    }

    static func titleCase(_ term: String) -> String {
        term.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static func wordFrequencies(_ texts: [String], language: String) -> [String: Int] {
        guard !texts.isEmpty else { return [:] }
        // Reviews mix languages; filter with both lists plus the requested one.
        let stops = (stopwords[language] ?? []).union(stopwords["en"] ?? []).union(stopwords["de"] ?? [])
        var freq: [String: Int] = [:]
        for text in texts {
            for word in text.lowercased().split(whereSeparator: { !($0.isLetter || $0.isNumber) }) {
                let w = String(word)
                guard w.count > 3, !stops.contains(w) else { continue }
                freq[w, default: 0] += 1
            }
        }
        return freq
    }
}

// MARK: - Research report

public enum ASOResearchReport {
    /// Markdown research summary — written next to `AGENT_BRIEF.md` so a metadata-writing
    /// agent (or a human) can base copy on actual keyword data.
    public static func markdown(appName: String, country: String, input: ASOInput,
                                proposal: ASOProposal) -> String {
        var s = "# ASO research — \(appName) (\(country.uppercased()))\n\n"
        s += "_Generated by ASC Manager from Appfigures keyword data, the current App Store metadata, and customer reviews._\n\n"

        s += "## Proposed keyword field (\(proposal.keywordField.count)/\(input.keywordLimit) chars)\n\n"
        s += "```\n\(proposal.keywordField)\n```\n\n"
        if let current = input.currentKeywords, !current.isEmpty {
            s += "Current field (\(current.count)/\(input.keywordLimit) chars):\n\n```\n\(current)\n```\n\n"
        }

        if !proposal.titleSuggestions.isEmpty {
            s += "## Title ideas (≤ \(ASOAgentEngine.nameLimit) chars)\n"
            for t in proposal.titleSuggestions { s += "- \(t)\n" }
            s += "\n"
        }
        if !proposal.subtitleSuggestions.isEmpty {
            s += "## Subtitle ideas (≤ \(ASOAgentEngine.subtitleLimit) chars)\n"
            for t in proposal.subtitleSuggestions { s += "- \(t)\n" }
            s += "\n"
        }

        s += "## Keyword candidates\n\n"
        s += "| Term | Score | Popularity | Competitiveness | Rank | Sources | In name/subtitle |\n"
        s += "|---|---|---|---|---|---|---|\n"
        for c in proposal.candidates {
            let sources = c.sources.map(\.rawValue).sorted().joined(separator: ", ")
            s += "| \(c.term) | \(format(c.score)) | \(format(c.popularity)) | \(format(c.competitiveness)) "
            s += "| \(c.position.map(String.init) ?? "—") | \(sources) | \(c.coveredByTitle ? "yes" : "") |\n"
        }
        s += "\n"

        if !proposal.warnings.isEmpty {
            s += "## Findings on the current metadata\n"
            for warning in proposal.warnings { s += "- \(describe(warning))\n" }
            s += "\n"
        }
        return s
    }

    private static func format(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }

    /// English-only report wording (the report is a file for agents/tools, not UI).
    private static func describe(_ warning: ASOWarning) -> String {
        switch warning {
        case .spacesAfterCommas(let count):
            return "\(count) space(s) after commas in the keyword field waste characters."
        case .duplicateWords(let words):
            return "Duplicated words in the keyword field: \(words.joined(separator: ", "))."
        case .titleDuplicates(let words):
            return "Words already covered by the name/subtitle: \(words.joined(separator: ", "))."
        case .overLimit(let current, let max):
            return "Keyword field is \(current) chars — over the \(max)-char limit."
        case .reservedWords(let words):
            return "Words Apple ignores in keywords: \(words.joined(separator: ", "))."
        case .unusedBudget(let remaining):
            return "\(remaining) characters of the keyword budget are unused — consider more research terms."
        }
    }
}
