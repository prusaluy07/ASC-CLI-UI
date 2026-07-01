import Foundation

/// Apple's fiscal payout schedule (approximate payment dates for App Store proceeds).
public struct AppleFiscalPeriod: Sendable, Identifiable, Equatable {
    public var id: String { "\(fiscalYear)-\(fiscalMonth)" }
    public let fiscalYear: Int
    public let fiscalMonth: Int
    public let periodStart: Date
    public let periodEnd: Date
    public let paymentDate: Date

    public init(fiscalYear: Int, fiscalMonth: Int, periodStart: Date, periodEnd: Date, paymentDate: Date) {
        self.fiscalYear = fiscalYear
        self.fiscalMonth = fiscalMonth
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.paymentDate = paymentDate
    }
}

public enum AppleFiscalCalendar {
    /// Known Apple fiscal periods for 2025–2026 (payment dates are when Apple typically wires proceeds).
    private static let periods: [AppleFiscalPeriod] = {
        let cal = Calendar(identifier: .gregorian)
        func d(_ y: Int, _ m: Int, _ day: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: day)) ?? .distantPast
        }
        return [
            AppleFiscalPeriod(fiscalYear: 2025, fiscalMonth: 1, periodStart: d(2024, 9, 29), periodEnd: d(2024, 11, 2), paymentDate: d(2024, 12, 5)),
            AppleFiscalPeriod(fiscalYear: 2025, fiscalMonth: 2, periodStart: d(2024, 11, 3), periodEnd: d(2024, 11, 30), paymentDate: d(2025, 1, 2)),
            AppleFiscalPeriod(fiscalYear: 2025, fiscalMonth: 3, periodStart: d(2024, 12, 1), periodEnd: d(2025, 1, 4), paymentDate: d(2025, 2, 6)),
            AppleFiscalPeriod(fiscalYear: 2025, fiscalMonth: 4, periodStart: d(2025, 1, 5), periodEnd: d(2025, 2, 1), paymentDate: d(2025, 3, 6)),
            AppleFiscalPeriod(fiscalYear: 2025, fiscalMonth: 5, periodStart: d(2025, 2, 2), periodEnd: d(2025, 3, 1), paymentDate: d(2025, 4, 3)),
            AppleFiscalPeriod(fiscalYear: 2025, fiscalMonth: 6, periodStart: d(2025, 3, 2), periodEnd: d(2025, 4, 5), paymentDate: d(2025, 5, 8)),
            AppleFiscalPeriod(fiscalYear: 2025, fiscalMonth: 7, periodStart: d(2025, 4, 6), periodEnd: d(2025, 5, 3), paymentDate: d(2025, 6, 5)),
            AppleFiscalPeriod(fiscalYear: 2025, fiscalMonth: 8, periodStart: d(2025, 5, 4), periodEnd: d(2025, 5, 31), paymentDate: d(2025, 7, 3)),
            AppleFiscalPeriod(fiscalYear: 2025, fiscalMonth: 9, periodStart: d(2025, 6, 1), periodEnd: d(2025, 7, 5), paymentDate: d(2025, 8, 7)),
            AppleFiscalPeriod(fiscalYear: 2025, fiscalMonth: 10, periodStart: d(2025, 7, 6), periodEnd: d(2025, 8, 2), paymentDate: d(2025, 9, 4)),
            AppleFiscalPeriod(fiscalYear: 2025, fiscalMonth: 11, periodStart: d(2025, 8, 3), periodEnd: d(2025, 8, 30), paymentDate: d(2025, 10, 2)),
            AppleFiscalPeriod(fiscalYear: 2025, fiscalMonth: 12, periodStart: d(2025, 8, 31), periodEnd: d(2025, 10, 4), paymentDate: d(2025, 11, 6)),
            AppleFiscalPeriod(fiscalYear: 2026, fiscalMonth: 1, periodStart: d(2025, 10, 5), periodEnd: d(2025, 11, 1), paymentDate: d(2025, 12, 4)),
            AppleFiscalPeriod(fiscalYear: 2026, fiscalMonth: 2, periodStart: d(2025, 11, 2), periodEnd: d(2025, 11, 29), paymentDate: d(2026, 1, 2)),
            AppleFiscalPeriod(fiscalYear: 2026, fiscalMonth: 3, periodStart: d(2025, 11, 30), periodEnd: d(2026, 1, 3), paymentDate: d(2026, 2, 5)),
            AppleFiscalPeriod(fiscalYear: 2026, fiscalMonth: 4, periodStart: d(2026, 1, 4), periodEnd: d(2026, 1, 31), paymentDate: d(2026, 3, 5)),
            AppleFiscalPeriod(fiscalYear: 2026, fiscalMonth: 5, periodStart: d(2026, 2, 1), periodEnd: d(2026, 2, 28), paymentDate: d(2026, 4, 2)),
            AppleFiscalPeriod(fiscalYear: 2026, fiscalMonth: 6, periodStart: d(2026, 3, 1), periodEnd: d(2026, 4, 4), paymentDate: d(2026, 5, 7)),
        ]
    }()

    public static func period(containing date: Date = .now) -> AppleFiscalPeriod? {
        periods.first { date >= $0.periodStart && date <= $0.periodEnd }
    }

    public static func nextPayment(after date: Date = .now) -> AppleFiscalPeriod? {
        periods.first { $0.paymentDate >= date }
    }

    public static func allPeriods() -> [AppleFiscalPeriod] { periods }
}
