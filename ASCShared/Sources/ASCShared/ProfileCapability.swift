import Foundation

// MARK: - API key capability (which profile to use for which class of ASC commands)

/// Maps stored `asc` credential profiles to the kinds of App Store Connect operations
/// that need different API key access levels (Apple roles).
public enum ProfileCapability: String, CaseIterable, Codable, Identifiable, Hashable {
    /// Day-to-day operations: apps, builds, metadata, TestFlight, etc.
    case general
    /// App Analytics insights and report requests (Admin / Account Holder).
    case analytics
    /// Sales and finance reports (vendor-number based).
    case finance
    /// Team management: user invites, elevated account operations.
    case admin

    public var id: String { rawValue }

    /// UserDefaults key for the profile name assigned to this capability.
    public var settingsKey: String { "asc.profile.\(rawValue)" }

    /// Localization key for the capability label in Settings.
    public var locKey: LocKey {
        switch self {
        case .general:   return .profileCapGeneral
        case .analytics: return .profileCapAnalytics
        case .finance:   return .profileCapFinance
        case .admin:     return .profileCapAdmin
        }
    }

    /// Short help text localization key.
    public var helpLocKey: LocKey {
        switch self {
        case .general:   return .profileCapGeneralHelp
        case .analytics: return .profileCapAnalyticsHelp
        case .finance:   return .profileCapFinanceHelp
        case .admin:     return .profileCapAdminHelp
        }
    }

    /// Capabilities that can be assigned a dedicated profile (`.general` uses `activeProfile`).
    public static var assignable: [ProfileCapability] {
        [.analytics, .finance, .admin]
    }
}

// MARK: - Persistence

public enum ProfileCapabilitySettings {
    public static let storageKey = "asc.profileMappings"

    /// Decodes a capability → profile name map from UserDefaults raw value.
    public static func decode(_ raw: String) -> [ProfileCapability: String] {
        guard let data = raw.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        var result: [ProfileCapability: String] = [:]
        for (key, value) in dict {
            if let cap = ProfileCapability(rawValue: key), !value.isEmpty {
                result[cap] = value
            }
        }
        return result
    }

    public static func encode(_ map: [ProfileCapability: String]) -> String {
        let dict = Dictionary(uniqueKeysWithValues: map.map { ($0.key.rawValue, $0.value) })
        guard let data = try? JSONEncoder().encode(dict),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    /// Reads the stored map from UserDefaults.
    public static func load(from defaults: UserDefaults = .standard) -> [ProfileCapability: String] {
        decode(defaults.string(forKey: storageKey) ?? "{}")
    }

    /// Writes the map to UserDefaults.
    public static func save(_ map: [ProfileCapability: String], to defaults: UserDefaults = .standard) {
        defaults.set(encode(map), forKey: storageKey)
    }

    /// Drops mappings that no longer match a known credential name.
    public static func prune(_ map: [ProfileCapability: String], validNames: Set<String>) -> [ProfileCapability: String] {
        map.filter { validNames.contains($0.value) }
    }
}
