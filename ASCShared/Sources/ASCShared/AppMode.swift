import Foundation

/// App-wide data mode: whether the app works against **live** App Store Connect data
/// (`online`) or from **local files / cached data** with no automatic network calls
/// (`offline`).
///
/// This used to be a Metadata-only, transient picker; it is now a single global setting
/// (persisted under `asc.globalMode`) that every screen reflects in its header and that the
/// app honors when deciding whether to auto-fetch from the network.
public enum AppMode: String, CaseIterable, Identifiable, Sendable {
    case online
    case offline

    public var id: String { rawValue }

    /// Short label shown in the header badge and the Overview selector.
    public var locKey: LocKey {
        switch self {
        case .online:  return .modeOnline
        case .offline: return .modeOffline
        }
    }

    /// One-line explanation shown under the Overview selector.
    public var descriptionKey: LocKey {
        switch self {
        case .online:  return .modeOnlineDesc
        case .offline: return .modeOfflineDesc
        }
    }

    /// SF Symbol representing the mode.
    public var iconName: String {
        switch self {
        case .online:  return "cloud.fill"
        case .offline: return "internaldrive.fill"
        }
    }

    /// The opposite mode (used by the one-tap header badge toggle).
    public var toggled: AppMode { self == .online ? .offline : .online }
}
