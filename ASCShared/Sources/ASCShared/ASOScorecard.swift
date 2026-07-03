import Foundation

/// Grades the *current* App Store metadata (not the proposal) so users see at a
/// glance where characters are being wasted. Pure function of the agent input
/// and the findings the engine already produced.
public struct ASOScorecard: Sendable, Equatable {
    public struct Item: Sendable, Equatable, Identifiable {
        public enum Kind: String, Sendable, CaseIterable {
            /// How much of the 100-char keyword budget is used.
            case keywordBudget
            /// No duplicated / title-covered / reserved words, no spaces after commas.
            case cleanliness
            /// How much of the 30-char app-name budget is used.
            case titleUsage
            /// How much of the 30-char subtitle budget is used.
            case subtitleUsage
        }

        public let kind: Kind
        public let points: Int
        public let maxPoints: Int
        public var id: String { kind.rawValue }

        public init(kind: Kind, points: Int, maxPoints: Int) {
            self.kind = kind
            self.points = points
            self.maxPoints = maxPoints
        }
    }

    public let items: [Item]
    public var total: Int { items.reduce(0) { $0 + $1.points } }
    public var maxTotal: Int { items.reduce(0) { $0 + $1.maxPoints } }

    public init(items: [Item]) {
        self.items = items
    }

    public static func evaluate(input: ASOInput, warnings: [ASOWarning]) -> ASOScorecard {
        var items: [Item] = []

        // Keyword budget (30): every unused character is a lost ranking chance.
        let fieldLength = min(input.currentKeywords?.count ?? 0, input.keywordLimit)
        items.append(Item(kind: .keywordBudget,
                          points: scaled(fieldLength, of: input.keywordLimit, max: 30),
                          maxPoints: 30))

        // Cleanliness (30): −8 per distinct current-field finding.
        let fieldFindings = warnings.filter { warning in
            switch warning {
            case .spacesAfterCommas, .duplicateWords, .titleDuplicates, .overLimit, .reservedWords:
                return true
            case .unusedBudget:
                return false
            }
        }
        items.append(Item(kind: .cleanliness,
                          points: max(30 - fieldFindings.count * 8, 0),
                          maxPoints: 30))

        // Name & subtitle usage (20 each): Apple indexes both, so short ones waste reach.
        items.append(Item(kind: .titleUsage,
                          points: scaled(min(input.appName.count, ASOAgentEngine.nameLimit),
                                         of: ASOAgentEngine.nameLimit, max: 20),
                          maxPoints: 20))
        let subtitleLength = min(input.subtitle?.count ?? 0, ASOAgentEngine.subtitleLimit)
        items.append(Item(kind: .subtitleUsage,
                          points: scaled(subtitleLength, of: ASOAgentEngine.subtitleLimit, max: 20),
                          maxPoints: 20))

        return ASOScorecard(items: items)
    }

    private static func scaled(_ value: Int, of limit: Int, max maxPoints: Int) -> Int {
        guard limit > 0 else { return 0 }
        return Int((Double(value) / Double(limit) * Double(maxPoints)).rounded())
    }
}
