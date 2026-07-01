import Foundation

/// A simplified market-activity index derived from public chart rank movements.
public struct MarketIndexResult: Sendable, Equatable {
    /// Signed score: positive = upward chart momentum, negative = downward.
    public let score: Double
    /// Human-readable direction label key suffix: "up", "down", "flat".
    public let direction: String
    /// How many apps in the compared window moved up vs down.
    public let upwardMoves: Int
    public let downwardMoves: Int
    public let newEntrants: Int
    public let comparedCount: Int

    public init(score: Double,
                direction: String,
                upwardMoves: Int,
                downwardMoves: Int,
                newEntrants: Int,
                comparedCount: Int) {
        self.score = score
        self.direction = direction
        self.upwardMoves = upwardMoves
        self.downwardMoves = downwardMoves
        self.newEntrants = newEntrants
        self.comparedCount = comparedCount
    }
}

public enum MarketIndexCalculator {
    /// Compares the latest chart snapshot to the previous one for the same key.
    /// Score is the average rank improvement (previousRank − currentRank) across
    /// apps present in both snapshots, plus a small bonus for new entrants.
    public static func compute(current: ChartSnapshot, previous: ChartSnapshot?) -> MarketIndexResult? {
        guard !current.entries.isEmpty else { return nil }
        guard let previous, !previous.entries.isEmpty else {
            return MarketIndexResult(
                score: 0, direction: "flat",
                upwardMoves: 0, downwardMoves: 0, newEntrants: 0,
                comparedCount: current.entries.count
            )
        }

        let prevRanks = Dictionary(uniqueKeysWithValues: previous.entries.map { ($0.id, $0.rank) })
        var deltas: [Double] = []
        var upward = 0
        var downward = 0
        var newEntrants = 0

        for entry in current.entries {
            if let prevRank = prevRanks[entry.id] {
                let delta = Double(prevRank - entry.rank) // positive = climbed
                deltas.append(delta)
                if delta > 0 { upward += 1 }
                else if delta < 0 { downward += 1 }
            } else {
                newEntrants += 1
            }
        }

        let avgDelta = deltas.isEmpty ? 0 : deltas.reduce(0, +) / Double(deltas.count)
        let bonus = Double(newEntrants) * 0.5
        let score = avgDelta + bonus
        let direction: String
        if score > 0.25 { direction = "up" }
        else if score < -0.25 { direction = "down" }
        else { direction = "flat" }

        return MarketIndexResult(
            score: score,
            direction: direction,
            upwardMoves: upward,
            downwardMoves: downward,
            newEntrants: newEntrants,
            comparedCount: current.entries.count
        )
    }

    /// Finds a bookmarked app in the chart and returns its rank delta vs the previous snapshot.
    public static func rankDelta(for appId: String,
                                 current: ChartSnapshot,
                                 previous: ChartSnapshot?) -> Int? {
        guard let previous,
              let currentRank = current.entries.first(where: { $0.id == appId })?.rank,
              let prevRank = previous.entries.first(where: { $0.id == appId })?.rank else {
            return nil
        }
        return prevRank - currentRank
    }
}
