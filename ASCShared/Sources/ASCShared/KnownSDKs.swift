import Foundation

public struct KnownSDK: Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let vendor: String
    public let category: String
    public let keywords: [String]

    public init(id: String, name: String, vendor: String, category: String, keywords: [String]) {
        self.id = id
        self.name = name
        self.vendor = vendor
        self.category = category
        self.keywords = keywords
    }
}

public struct SDKChartMatch: Sendable, Identifiable, Equatable {
    public var id: String { "\(sdk.id):\(app.id)" }
    public let sdk: KnownSDK
    public let app: AppStoreChartEntry
    public let matchedKeyword: String

    public init(sdk: KnownSDK, app: AppStoreChartEntry, matchedKeyword: String) {
        self.sdk = sdk
        self.app = app
        self.matchedKeyword = matchedKeyword
    }
}

/// Curated list of well-known mobile SDKs with lightweight keyword heuristics.
public enum KnownSDKCatalog {
    public static let all: [KnownSDK] = [
        KnownSDK(id: "firebase", name: "Firebase", vendor: "Google",
                 category: "Analytics", keywords: ["firebase", "google analytics for firebase"]),
        KnownSDK(id: "revenuecat", name: "RevenueCat", vendor: "RevenueCat",
                 category: "Subscriptions", keywords: ["revenuecat", "purchases"]),
        KnownSDK(id: "amplitude", name: "Amplitude", vendor: "Amplitude",
                 category: "Analytics", keywords: ["amplitude"]),
        KnownSDK(id: "mixpanel", name: "Mixpanel", vendor: "Mixpanel",
                 category: "Analytics", keywords: ["mixpanel"]),
        KnownSDK(id: "sentry", name: "Sentry", vendor: "Sentry",
                 category: "Crash reporting", keywords: ["sentry"]),
        KnownSDK(id: "onesignal", name: "OneSignal", vendor: "OneSignal",
                 category: "Push", keywords: ["onesignal"]),
        KnownSDK(id: "adjust", name: "Adjust", vendor: "Adjust",
                 category: "Attribution", keywords: ["adjust"]),
        KnownSDK(id: "appsflyer", name: "AppsFlyer", vendor: "AppsFlyer",
                 category: "Attribution", keywords: ["appsflyer"]),
        KnownSDK(id: "branch", name: "Branch", vendor: "Branch",
                 category: "Deep linking", keywords: ["branch.io", "branch"]),
        KnownSDK(id: "stripe", name: "Stripe", vendor: "Stripe",
                 category: "Payments", keywords: ["stripe"]),
        KnownSDK(id: "superwall", name: "Superwall", vendor: "Superwall",
                 category: "Paywalls", keywords: ["superwall"]),
        KnownSDK(id: "adapty", name: "Adapty", vendor: "Adapty",
                 category: "Subscriptions", keywords: ["adapty"]),
    ]

    /// Matches SDK keywords against chart app names (light heuristic — not Appfigures-level).
    public static func matches(in entries: [AppStoreChartEntry]) -> [SDKChartMatch] {
        var results: [SDKChartMatch] = []
        var seen = Set<String>()
        for entry in entries {
            let haystack = entry.name.lowercased()
            for sdk in all {
                for keyword in sdk.keywords {
                    if haystack.contains(keyword.lowercased()) {
                        let key = "\(sdk.id):\(entry.id)"
                        guard !seen.contains(key) else { continue }
                        seen.insert(key)
                        results.append(SDKChartMatch(sdk: sdk, app: entry, matchedKeyword: keyword))
                    }
                }
            }
        }
        return results.sorted { $0.sdk.name < $1.sdk.name }
    }

    /// Matches SDK keywords against iTunes app descriptions.
    public static func matches(in apps: [ITunesAppResult]) -> [KnownSDK: [ITunesAppResult]] {
        var map: [KnownSDK: [ITunesAppResult]] = [:]
        for app in apps {
            let haystack = ((app.description ?? "") + " " + app.trackName).lowercased()
            for sdk in all {
                if sdk.keywords.contains(where: { haystack.contains($0.lowercased()) }) {
                    map[sdk, default: []].append(app)
                }
            }
        }
        return map
    }
}
