import Foundation

// MARK: - Snapshot

public struct ChartSnapshot: Sendable, Codable, Equatable, Identifiable {
    public var id: String { key }
    public let key: String
    public let capturedAt: Date
    public let country: String
    public let category: AppStoreChartCategory
    public let kind: AppStoreChartKind
    public let entries: [AppStoreChartEntry]

    public init(key: String,
                capturedAt: Date = Date(),
                country: String,
                category: AppStoreChartCategory,
                kind: AppStoreChartKind,
                entries: [AppStoreChartEntry]) {
        self.key = key
        self.capturedAt = capturedAt
        self.country = country
        self.category = category
        self.kind = kind
        self.entries = entries
    }
}

// MARK: - Store

/// Persists chart snapshots locally so market-index trends can be computed offline.
public final class ChartHistoryStore: @unchecked Sendable {
    private struct Snapshot: Codable {
        var history: [String: [ChartSnapshot]]
        var bookmarks: Set<String>
    }

    private let fileURL: URL
    private let lock = NSLock()
    private var data = Snapshot(history: [:], bookmarks: [])

    public init(filename: String = "chart-history.json") {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true))?
            .appendingPathComponent("ASCManager", isDirectory: true)
        if let base {
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            fileURL = base.appendingPathComponent(filename)
        } else {
            fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        }
        load()
    }

    public static func key(country: String,
                           category: AppStoreChartCategory,
                           kind: AppStoreChartKind) -> String {
        "\(country.lowercased()):\(category.rawValue):\(kind.rawValue)"
    }

    public var bookmarkedAppIds: Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return data.bookmarks
    }

    public func isBookmarked(_ appId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return data.bookmarks.contains(appId)
    }

    public func toggleBookmark(_ appId: String) {
        lock.lock()
        if data.bookmarks.contains(appId) {
            data.bookmarks.remove(appId)
        } else {
            data.bookmarks.insert(appId)
        }
        lock.unlock()
        save()
    }

    /// Saves a feed snapshot, keeping the last 30 per chart key.
    @discardableResult
    public func record(_ feed: AppStoreChartsFeed) -> ChartSnapshot {
        let key = feed.cacheKey
        let snap = ChartSnapshot(
            key: key,
            country: feed.country,
            category: feed.category,
            kind: feed.kind,
            entries: feed.entries
        )
        lock.lock()
        var list = data.history[key] ?? []
        list.append(snap)
        if list.count > 30 { list.removeFirst(list.count - 30) }
        data.history[key] = list
        lock.unlock()
        save()
        return snap
    }

    public func latest(for key: String) -> ChartSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return data.history[key]?.last
    }

    public func previous(for key: String) -> ChartSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard let list = data.history[key], list.count >= 2 else { return nil }
        return list[list.count - 2]
    }

    public func history(for key: String) -> [ChartSnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return data.history[key] ?? []
    }

    public func allKeys() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(data.history.keys).sorted()
    }

    public func exportJSON() -> String {
        lock.lock()
        let snapshot = data
        lock.unlock()
        guard let encoded = try? JSONEncoder().encode(snapshot),
              let text = String(data: encoded, encoding: .utf8) else { return "{}" }
        return text
    }

    private func load() {
        guard let raw = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(Snapshot.self, from: raw) else { return }
        data = decoded
    }

    private func save() {
        lock.lock()
        let snapshot = data
        lock.unlock()
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        try? encoded.write(to: fileURL, options: .atomic)
    }
}
