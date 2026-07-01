import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ASCShared

// MARK: - Pricing

struct PricingView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    var body: some View {
        CommandScreen(title: loc(.secPricing), subtitle: selectedApp?.name, intro: loc(.prBody),
                      requireApp: true, hasApp: selectedApp != nil) { _, _ in
            VStack(alignment: .leading, spacing: 14) {
                CommandSection(title: loc(.prCurrent), systemImage: "dollarsign.circle",
                               autoRun: { await ascService.pricingCurrent(appId: selectedApp?.id ?? "") },
                               autoRunToken: selectedApp?.id ?? "") { run, isRunning in
                    Button { run { await ascService.pricingCurrent(appId: selectedApp?.id ?? "") } } label: {
                        Label(loc(.refresh), systemImage: "arrow.clockwise")
                    }.disabled(isRunning)
                }
                CommandSection(title: loc(.prSchedule), systemImage: "calendar",
                               autoRun: { await ascService.pricingSchedule(appId: selectedApp?.id ?? "") },
                               autoRunToken: selectedApp?.id ?? "") { run, isRunning in
                    Button { run { await ascService.pricingSchedule(appId: selectedApp?.id ?? "") } } label: {
                        Label(loc(.refresh), systemImage: "arrow.clockwise")
                    }.disabled(isRunning)
                }
                CommandSection(title: loc(.prAvailability), systemImage: "map",
                               autoRun: { await ascService.pricingAvailability(appId: selectedApp?.id ?? "") },
                               autoRunToken: selectedApp?.id ?? "") { run, isRunning in
                    Button { run { await ascService.pricingAvailability(appId: selectedApp?.id ?? "") } } label: {
                        Label(loc(.refresh), systemImage: "arrow.clockwise")
                    }.disabled(isRunning)
                }
                CommandSection(title: loc(.prPricePoints), systemImage: "list.number") { run, isRunning in
                    Button { run { await ascService.pricingPricePoints(appId: selectedApp?.id ?? "") } } label: {
                        Label(loc(.actList), systemImage: "list.number")
                    }.disabled(isRunning)
                }
                CommandSection(title: loc(.prTerritories), systemImage: "globe") { run, isRunning in
                    Button { run { await ascService.pricingTerritories() } } label: {
                        Label(loc(.actList), systemImage: "globe")
                    }.disabled(isRunning)
                }
            }
        }
    }
}

// MARK: - Reviews

struct ReviewsView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    @State private var stars = 0
    @State private var territory = ""
    @State private var onlyUnresponded = false
    @State private var searchText = ""
    @State private var reviews: [CustomerReview] = []
    @State private var ratings: ReviewRatingsSummary?
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var reviewId = ""
    @State private var responseText = ""

    private var filteredReviews: [CustomerReview] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return reviews }
        return reviews.filter {
            ($0.title ?? "").lowercased().contains(q)
            || ($0.body ?? "").lowercased().contains(q)
            || ($0.reviewerNickname ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.secReviews), subtitle: selectedApp?.name) {
                Button { Task { await loadReviews() } } label: {
                    Label(loc(.refresh), systemImage: "arrow.clockwise")
                }
                .disabled(isLoading || selectedApp == nil)
            }
            Divider()

            if selectedApp == nil {
                ContentUnavailableView(loc(.noAppSelectedTitle), systemImage: "star.bubble",
                                       description: Text(loc(.selectAppFromApps)))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(loc(.rvBody)).font(.callout).foregroundStyle(.secondary)

                        if let ratings { ratingsCard(ratings) }

                        filtersRow

                        if isLoading {
                            ProgressView(loc(.load)).frame(maxWidth: .infinity)
                        } else if let loadError {
                            Text(loadError).font(.caption).foregroundStyle(.red)
                        } else if reviews.isEmpty {
                            ContentUnavailableView(loc(.rvReviews), systemImage: "text.bubble")
                        } else {
                            reviewsTable
                        }

                        respondSection
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .task(id: selectedApp?.id) {
            await loadRatings()
            await loadReviews()
        }
    }

    private func ratingsCard(_ ratings: ReviewRatingsSummary) -> some View {
        GroupBox {
            HStack(spacing: 20) {
                if let avg = ratings.averageRating {
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", avg)).font(.title.weight(.bold))
                        Text(loc(.rvAvgRating)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let count = ratings.ratingCount {
                    VStack(spacing: 2) {
                        Text("\(count)").font(.title2.weight(.semibold))
                        Text(loc(.rvTotalRatings)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { exportReviews(format: .csv) } label: {
                    Label(loc(.exportCSV), systemImage: "square.and.arrow.up")
                }
                Button { exportReviews(format: .json) } label: {
                    Label(loc(.exportJSON), systemImage: "curlybraces")
                }
            }
            .padding(6)
        } label: {
            Label(loc(.rvRatingsSummary), systemImage: "star.fill")
        }
    }

    private var filtersRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowButtons {
                Picker(loc(.rvStars), selection: $stars) {
                    Text(loc(.rvStarsAll)).tag(0)
                    ForEach(1...5, id: \.self) { Text("\($0)★").tag($0) }
                }
                .frame(maxWidth: 140)
                TextField(loc(.rvTerritory), text: $territory)
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 120)
                Toggle(loc(.rvOnlyUnresponded), isOn: $onlyUnresponded).toggleStyle(.checkbox)
                Button { Task { await loadReviews() } } label: {
                    Label(loc(.actList), systemImage: "list.bullet")
                }
                .disabled(isLoading)
            }
            TextField(loc(.rvSearch), text: $searchText)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var reviewsTable: some View {
        GroupBox {
            Table(filteredReviews) {
                TableColumn(loc(.rvStars)) { review in
                    if let rating = review.rating { Text("\(rating)★") }
                }
                .width(48)
                TableColumn(loc(.rvTerritory)) { review in
                    Text(review.territory ?? "—").font(.caption)
                }
                .width(56)
                TableColumn(loc(.rvDate)) { review in
                    Text(shortDate(review.createdDate)).font(.caption.monospacedDigit())
                }
                .width(100)
                TableColumn(loc(.rvTitle)) { review in
                    Text(review.title ?? "—").lineLimit(1)
                }
                TableColumn(loc(.rvBodyCol)) { review in
                    Text(review.body ?? "—").lineLimit(2).foregroundStyle(.secondary)
                }
                TableColumn("") { review in
                    Image(systemName: review.hasResponse ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(review.hasResponse ? .green : .secondary)
                        .help(review.hasResponse ? loc(.rvResponded) : loc(.rvNotResponded))
                }
                .width(32)
            }
            .frame(minHeight: 280)
        } label: {
            Label(loc(.rvTable), systemImage: "tablecells")
        }
    }

    private var respondSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                TextField(loc(.rvReviewId), text: $reviewId)
                    .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced))
                TextField(loc(.rvResponseText), text: $responseText, axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(3...6)
                HStack {
                    Spacer()
                    Button {
                        Task { await respond() }
                    } label: { Label(loc(.actRespond), systemImage: "arrowshape.turn.up.left") }
                    .buttonStyle(.borderedProminent)
                    .disabled(reviewId.isEmpty || responseText.isEmpty)
                }
            }
            .padding(4)
        } label: {
            Label(loc(.rvRespond), systemImage: "arrowshape.turn.up.left")
        }
    }

    private func loadRatings() async {
        guard let appId = selectedApp?.id else { ratings = nil; return }
        let result = await ascService.reviewsRatings(appId: appId)
        ratings = result.succeeded ? ReviewRatingsParser.parse(result.output) : nil
    }

    private func loadReviews() async {
        guard let appId = selectedApp?.id else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        let result = await ascService.reviewsList(
            appId: appId,
            stars: stars == 0 ? nil : stars,
            territory: territory,
            onlyUnresponded: onlyUnresponded
        )
        guard result.succeeded else {
            loadError = result.errorMessage
            reviews = []
            return
        }
        reviews = CustomerReviewParser.parse(result.output)
    }

    private func respond() async {
        let result = await ascService.reviewRespond(reviewId: reviewId, text: responseText)
        if result.succeeded {
            responseText = ""
            await loadReviews()
        } else {
            loadError = result.errorMessage
        }
    }

    private func shortDate(_ raw: String?) -> String {
        guard let raw, raw.count >= 10 else { return raw ?? "—" }
        return String(raw.prefix(10))
    }

    private enum ReviewExportFormat { case csv, json }

    private func exportReviews(format: ReviewExportFormat) {
        let text: String
        switch format {
        case .csv:
            var lines = ["id,rating,territory,title,body,created,responded"]
            for r in reviews {
                let fields = [
                    r.id,
                    r.rating.map(String.init) ?? "",
                    r.territory ?? "",
                    csvEscape(r.title ?? ""),
                    csvEscape(r.body ?? ""),
                    r.createdDate ?? "",
                    r.hasResponse ? "yes" : "no"
                ]
                lines.append(fields.joined(separator: ","))
            }
            text = lines.joined(separator: "\n")
        case .json:
            guard let data = try? JSONEncoder().encode(reviews),
                  let encoded = String(data: data, encoding: .utf8) else { return }
            text = encoded
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = format == .csv ? [.commaSeparatedText] : [.json]
        let name = selectedApp?.name ?? "reviews"
        panel.nameFieldStringValue = "\(name)-reviews.\(format == .csv ? "csv" : "json")"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
