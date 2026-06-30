import Foundation

/// App identity shared between the macOS app and the iPhone companion.
///
/// `bundleVersion` / `bundleBuild` resolve from whichever target embeds this package, while
/// `compatibleMacAppVersion` / `compatibleMacAppBuild` are constants the companion shows so
/// users know which **ASC Manager** (macOS) release this build is designed to mirror. Keep
/// the compatible-Mac constants in sync with the macOS target's MARKETING_VERSION /
/// CURRENT_PROJECT_VERSION.
public enum ASCAppInfo {
    /// Short version (`CFBundleShortVersionString`) of the running app.
    public static var bundleVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    /// Build number (`CFBundleVersion`) of the running app.
    public static var bundleBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    /// The macOS "ASC Manager" release this build is built to mirror.
    public static let compatibleMacAppVersion = "0.2"
    public static let compatibleMacAppBuild = "2"

    public static let creator = "Andre Ludwig"
    public static let license = "MIT License"
    public static let repositoryURL = URL(string: "https://github.com/prusaluy07/ASC-CLI-UI")!
}
