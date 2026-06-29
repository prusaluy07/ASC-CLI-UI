import Foundation

/// Decoded result of `asc metadata validate`, used to render a structured validation card
/// instead of raw JSON.
///
/// Example payload:
/// ```json
/// { "dir": "…", "filesScanned": 0, "errorCount": 1, "warningCount": 0, "valid": false,
///   "issues": [ { "scope": "metadata", "file": "…", "field": "metadata",
///                 "severity": "error", "message": "no metadata .json files found" } ] }
/// ```
public struct MetadataValidation: Decodable, Sendable, Equatable {
    public struct Issue: Decodable, Sendable, Equatable, Identifiable {
        public let scope: String?
        public let file: String?
        public let field: String?
        public let severity: String?
        public let message: String?

        public var id: String { "\(scope ?? "")|\(file ?? "")|\(field ?? "")|\(message ?? "")" }

        /// True for `severity == "error"` (case-insensitive); everything else is treated as a warning.
        public var isError: Bool { (severity ?? "").lowercased() == "error" }

        public init(scope: String?, file: String?, field: String?, severity: String?, message: String?) {
            self.scope = scope
            self.file = file
            self.field = field
            self.severity = severity
            self.message = message
        }
    }

    public let dir: String?
    public let filesScanned: Int?
    public let issues: [Issue]?
    public let errorCount: Int?
    public let warningCount: Int?
    public let valid: Bool?

    public init(dir: String?, filesScanned: Int?, issues: [Issue]?,
                errorCount: Int?, warningCount: Int?, valid: Bool?) {
        self.dir = dir
        self.filesScanned = filesScanned
        self.issues = issues
        self.errorCount = errorCount
        self.warningCount = warningCount
        self.valid = valid
    }

    public var orderedIssues: [Issue] {
        // Errors first, then warnings, preserving original order within each group.
        (issues ?? []).sorted { ($0.isError ? 0 : 1) < ($1.isError ? 0 : 1) }
    }

    /// Parses validation JSON, returning `nil` when the text isn't a recognizable validation
    /// result (so callers can fall back to a generic renderer for pull/apply output).
    public static func parse(_ text: String) -> MetadataValidation? {
        guard let data = text.data(using: .utf8),
              let value = try? JSONDecoder().decode(MetadataValidation.self, from: data),
              (value.valid != nil || value.issues != nil || value.errorCount != nil) else {
            return nil
        }
        return value
    }
}
