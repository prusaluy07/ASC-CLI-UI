import Foundation

// MARK: - Parsed sales row

/// One aggregated line from an Apple **Summary Sales** TSV (daily / weekly / monthly).
public struct SalesReportRow: Sendable, Hashable, Codable, Identifiable {
    public var id: String {
        "\(reportDate)|\(appleIdentifier)|\(sku)|\(productTypeIdentifier)|\(countryCode)|\(orderType ?? "")"
    }

    public let reportDate: String          // yyyy-MM-dd (Begin Date)
    public let appleIdentifier: String
    public let sku: String
    public let title: String
    public let productTypeIdentifier: String
    public let units: Int
    public let proceeds: Double            // Units × Developer Proceeds (per row)
    public let countryCode: String
    public let subscription: String?
    public let orderType: String?

    public init(reportDate: String,
                appleIdentifier: String,
                sku: String,
                title: String,
                productTypeIdentifier: String,
                units: Int,
                proceeds: Double,
                countryCode: String,
                subscription: String? = nil,
                orderType: String? = nil) {
        self.reportDate = reportDate
        self.appleIdentifier = appleIdentifier
        self.sku = sku
        self.title = title
        self.productTypeIdentifier = productTypeIdentifier
        self.units = units
        self.proceeds = proceeds
        self.countryCode = countryCode
        self.subscription = subscription
        self.orderType = orderType
    }

    public var isFirstDownload: Bool {
        SalesProductType.isFirstDownload(productTypeIdentifier)
    }

    public var isRedownload: Bool {
        SalesProductType.isRedownload(productTypeIdentifier)
    }

    public var isUpdate: Bool {
        SalesProductType.isUpdate(productTypeIdentifier)
    }

    public var isInAppPurchase: Bool {
        SalesProductType.isInAppPurchase(productTypeIdentifier)
    }

    public var isSubscription: Bool {
        SalesProductType.isSubscription(productTypeIdentifier, subscription: subscription)
    }

    /// Negative unit counts in Summary Sales reports represent returns/refunds.
    public var isReturn: Bool { units < 0 }
}

// MARK: - Product type helpers

public enum SalesProductType {
    private static let firstDownload = Set(["1", "1F", "1T", "F1"])
    private static let redownload = Set(["3", "3F"])
    private static let updates = Set(["7", "7F", "7T"])

    public static func isFirstDownload(_ type: String) -> Bool {
        firstDownload.contains(type.uppercased())
    }

    public static func isRedownload(_ type: String) -> Bool {
        redownload.contains(type.uppercased())
    }

    public static func isUpdate(_ type: String) -> Bool {
        updates.contains(type.uppercased())
    }

    public static func isInAppPurchase(_ type: String) -> Bool {
        let t = type.uppercased()
        return t.hasPrefix("IA") && !t.hasPrefix("IAY")
    }

    public static func isSubscription(_ type: String, subscription: String?) -> Bool {
        let t = type.uppercased()
        if t.hasPrefix("IAY") || t.hasPrefix("IA9") { return true }
        if let sub = subscription?.trimmingCharacters(in: .whitespaces), !sub.isEmpty { return true }
        return false
    }
}

// MARK: - Parser

/// Parses Apple Summary Sales TSV exports into normalized ``SalesReportRow`` values.
public enum SalesReportParser {
    public struct Result: Sendable {
        public let rows: [SalesReportRow]
        public let sourcePath: String?

        public init(rows: [SalesReportRow], sourcePath: String? = nil) {
            self.rows = rows
            self.sourcePath = sourcePath
        }
    }

    public static func parse(text: String, sourcePath: String? = nil) -> Result {
        let table = AnalyticsReportTable(text: text)
        guard !table.isEmpty else { return Result(rows: [], sourcePath: sourcePath) }

        let skuIdx = table.columnIndex(matching: ["sku"])
        let titleIdx = table.columnIndex(matching: ["title"])
        let typeIdx = table.columnIndex(matching: ["producttypeidentifier", "producttype"])
        let unitsIdx = table.columnIndex(matching: ["units"])
        let proceedsIdx = table.columnIndex(matching: ["developerproceeds", "proceeds"])
        let beginIdx = table.columnIndex(matching: ["begindate", "reportdate", "date"])
        let appleIdx = table.columnIndex(matching: ["appleidentifier", "appleid"])
        let countryIdx = table.columnIndex(matching: ["countrycode", "country"])
        let subIdx = table.columnIndex(matching: ["subscription"])
        let orderIdx = table.columnIndex(matching: ["ordertype"])

        guard let unitsIdx, let typeIdx else { return Result(rows: [], sourcePath: sourcePath) }

        func cell(_ row: [String], _ idx: Int?) -> String {
            guard let idx, idx < row.count else { return "" }
            return row[idx].trimmingCharacters(in: .whitespaces)
        }

        var rows: [SalesReportRow] = []
        for row in table.rows {
            let units = Int(cell(row, unitsIdx).replacingOccurrences(of: ",", with: "")) ?? 0
            guard units != 0 else { continue }

            let perUnit = AnalyticsReportTable.number(cell(row, proceedsIdx)) ?? 0
            let reportDate = normalizeDate(cell(row, beginIdx))
            let appleId = cell(row, appleIdx)
            let sku = cell(row, skuIdx)
            let productType = cell(row, typeIdx)

            rows.append(SalesReportRow(
                reportDate: reportDate,
                appleIdentifier: appleId,
                sku: sku,
                title: cell(row, titleIdx),
                productTypeIdentifier: productType,
                units: units,
                proceeds: Double(units) * perUnit,
                countryCode: cell(row, countryIdx),
                subscription: cell(row, subIdx).isEmpty ? nil : cell(row, subIdx),
                orderType: cell(row, orderIdx).isEmpty ? nil : cell(row, orderIdx)
            ))
        }
        return Result(rows: rows, sourcePath: sourcePath)
    }

    public static func parseFile(at path: String) -> Result? {
        guard let text = ReportFileReader.readText(at: path) else { return nil }
        return parse(text: text, sourcePath: path)
    }

    private static func normalizeDate(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.count == 8, trimmed.allSatisfy(\.isNumber) {
            // yyyyMMdd → yyyy-MM-dd
            let y = trimmed.prefix(4)
            let m = trimmed.dropFirst(4).prefix(2)
            let d = trimmed.suffix(2)
            return "\(y)-\(m)-\(d)"
        }
        if trimmed.count >= 10 { return String(trimmed.prefix(10)) }
        return trimmed
    }
}

// MARK: - File reader

public enum ReportFileReader {
    public static func readText(at path: String) -> String? {
        if path.lowercased().hasSuffix(".gz") {
            #if os(macOS)
            return gunzipContents(of: path)
            #else
            return nil
            #endif
        }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    #if os(macOS)
    private static func gunzipContents(of path: String) -> String? {
        let pipe = Pipe()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
        task.arguments = ["-c", path]
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
        } catch {
            return nil
        }
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
    #endif
}
