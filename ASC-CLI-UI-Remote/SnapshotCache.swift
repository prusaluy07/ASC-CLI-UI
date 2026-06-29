import Foundation
import ASCShared

/// Simple, robust offline cache for the latest fetched ``Snapshot`` set.
///
/// Why Codable-to-file instead of SwiftData: the data is a small, flat array that is
/// always replaced wholesale on every refresh (last-writer-wins, mirroring the producer).
/// There are no relationships, queries, or partial updates to model, so a single atomic
/// JSON file in Application Support is the simpler and more failure-tolerant option — it
/// can't throw migration/store-open errors and degrades to "no cache" instead of crashing.
///
/// All I/O is best-effort: a missing, unreadable or corrupt file simply yields an empty
/// cache, and write failures are swallowed (the next successful refresh recovers).
///
/// `nonisolated`: the project defaults to `MainActor` isolation, but this type holds no UI
/// state and performs only file I/O. Leaving it main-actor-isolated made the lazy
/// `static let shared` initializer (a nonisolated context) reach a main-actor-isolated
/// `init`, which both warns at compile time and traps at runtime ("Main actor-isolated
/// static property 'shared' can not be referenced from a nonisolated context"). Making it
/// `nonisolated` & `Sendable` fixes that and keeps disk I/O off the main actor.
nonisolated struct SnapshotCache: Sendable {
    static let shared = SnapshotCache()

    private let fileURL: URL

    init(filename: String = "mirror-cache.json") {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true))
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent(filename)
    }

    /// Loads the cached snapshots, or an empty array if nothing valid is stored.
    func load() -> [Snapshot] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Snapshot].self, from: data)) ?? []
    }

    /// Atomically persists the latest snapshots, replacing any previous cache.
    func save(_ snapshots: [Snapshot]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(snapshots) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Removes the cache file (used for testing / reset).
    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
