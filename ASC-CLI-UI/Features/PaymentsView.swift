import SwiftUI
import ASCShared

/// Tracks expected payouts from locally imported sales reports against Apple's fiscal calendar.
struct PaymentsView: View {
    @EnvironmentObject var loc: LocalizationManager
    @EnvironmentObject var metricsEngine: MetricsEngine
    let selectedApp: ASCApp?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static let moneyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        return f
    }()

    private var rows: [PaymentPeriodRow] {
        guard let app = selectedApp else { return [] }
        let now = Date()
        return AppleFiscalCalendar.allPeriods().reversed().prefix(12).map { period in
            let agg = metricsEngine.fiscalProceeds(for: app, period: period)
            let status: PaymentPeriodStatus
            if period.paymentDate > now {
                status = .upcoming
            } else if agg.isComplete {
                status = .paid
            } else {
                status = .incomplete
            }
            return PaymentPeriodRow(period: period, proceeds: agg.proceeds, status: status)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.secPayments), subtitle: selectedApp?.name) { EmptyView() }
            Divider()

            if selectedApp == nil {
                ContentUnavailableView(loc(.noAppSelectedTitle), systemImage: "banknote",
                                       description: Text(loc(.selectAppFromApps)))
            } else if !metricsEngine.hasData(for: selectedApp!) {
                ContentUnavailableView(loc(.payNoDataTitle), systemImage: "tray",
                                       description: Text(loc(.payNoDataBody)))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(loc(.payBody)).font(.callout).foregroundStyle(.secondary)

                        if let current = AppleFiscalCalendar.period() {
                            currentPeriodCard(current)
                        }

                        if rows.contains(where: { $0.status == .incomplete }) {
                            Label(loc(.payIncompleteHint), systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        paymentsTable
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func currentPeriodCard(_ period: AppleFiscalPeriod) -> some View {
        GroupBox {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc(.payCurrentPeriod)).font(.caption).foregroundStyle(.secondary)
                    Text(periodLabel(period)).font(.headline)
                }
                if let next = AppleFiscalCalendar.nextPayment() {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc(.msNextPayout)).font(.caption).foregroundStyle(.secondary)
                        Text(Self.dateFormatter.string(from: next.paymentDate)).font(.headline)
                    }
                }
                Spacer()
            }
            .padding(6)
        } label: {
            Label(loc(.payFiscalCalendar), systemImage: "calendar")
        }
    }

    private var paymentsTable: some View {
        GroupBox {
            Table(rows) {
                TableColumn(loc(.payPeriod)) { row in
                    Text(periodLabel(row.period)).font(.caption)
                }
                .width(min: 140, ideal: 180)
                TableColumn(loc(.payPaymentDate)) { row in
                    Text(Self.dateFormatter.string(from: row.period.paymentDate))
                        .font(.caption.monospacedDigit())
                }
                .width(min: 100, ideal: 120)
                TableColumn(loc(.payProceeds)) { row in
                    Text(formatMoney(row.proceeds))
                        .font(.callout.weight(.semibold))
                }
                .width(min: 90, ideal: 110)
                TableColumn(loc(.payStatus)) { row in
                    Text(statusLabel(row.status))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(statusColor(row.status))
                }
                .width(min: 90, ideal: 110)
            }
            .frame(minHeight: 320)
        } label: {
            Label(loc(.payHistory), systemImage: "list.bullet.rectangle")
        }
    }

    private func periodLabel(_ period: AppleFiscalPeriod) -> String {
        let start = Self.dateFormatter.string(from: period.periodStart)
        let end = Self.dateFormatter.string(from: period.periodEnd)
        return "\(start) – \(end)"
    }

    private func formatMoney(_ value: Double) -> String {
        Self.moneyFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func statusLabel(_ status: PaymentPeriodStatus) -> String {
        switch status {
        case .upcoming:   return loc(.payStatusUpcoming)
        case .paid:       return loc(.payStatusPaid)
        case .incomplete: return loc(.payStatusIncomplete)
        }
    }

    private func statusColor(_ status: PaymentPeriodStatus) -> Color {
        switch status {
        case .upcoming:   return .secondary
        case .paid:       return .green
        case .incomplete: return .orange
        }
    }
}

private enum PaymentPeriodStatus {
    case upcoming, paid, incomplete
}

private struct PaymentPeriodRow: Identifiable {
    let period: AppleFiscalPeriod
    let proceeds: Double
    let status: PaymentPeriodStatus
    var id: String { period.id }
}
