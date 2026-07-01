import SwiftUI
import ASCShared

struct MarketSearchView: View {
    @EnvironmentObject var loc: LocalizationManager
    @EnvironmentObject var market: MarketEngine

    @State private var query = ""
    @State private var results: [ITunesAppResult] = []
    @State private var selected: ITunesAppResult?
    @State private var isSearching = false
    @State private var searchError: String?

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.secMarketSearch), subtitle: market.country.uppercased()) {
                EmptyView()
            }
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(loc(.mktSearchBody)).font(.callout).foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        TextField(loc(.mktSearchPlaceholder), text: $query)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { Task { await search() } }
                        Picker(loc(.mktCountry), selection: Binding(
                            get: { market.country },
                            set: { market.setCountry($0) }
                        )) {
                            ForEach(MarketEngine.supportedCountries, id: \.code) { c in
                                Text(c.label).tag(c.code)
                            }
                        }
                        .frame(width: 160)
                        Button { Task { await search() } } label: {
                            Label(loc(.discSearch), systemImage: "magnifyingglass")
                        }
                        .disabled(isSearching || query.trimmingCharacters(in: .whitespaces).isEmpty)
                        if isSearching { ProgressView().controlSize(.small) }
                    }

                    if let searchError {
                        Text(searchError).font(.caption).foregroundStyle(.red)
                    }

                    if results.isEmpty, !isSearching, !query.isEmpty {
                        ContentUnavailableView(loc(.mktNoResults), systemImage: "magnifyingglass")
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(results) { app in
                                SearchResultRow(app: app) { selected = app }
                                if app.id != results.last?.id { Divider() }
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .sheet(item: $selected) { app in
            NavigationStack {
                ITunesAppDetailView(app: app)
                    .navigationTitle(app.trackName)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(loc(.close)) { selected = nil }
                        }
                    }
            }
            .frame(minWidth: 520, minHeight: 560)
        }
    }

    private func search() async {
        let term = query.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        isSearching = true
        searchError = nil
        defer { isSearching = false }
        do {
            if term.contains("."), !term.contains(" ") {
                if let byBundle = try await ITunesSearchClient.lookup(bundleId: term, country: market.country) {
                    results = [byBundle]
                    return
                }
            }
            results = try await ITunesSearchClient.search(term: term, country: market.country)
        } catch {
            searchError = error.localizedDescription
            results = []
        }
    }
}

private struct SearchResultRow: View {
    @EnvironmentObject var loc: LocalizationManager
    let app: ITunesAppResult
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                if let url = app.artworkUrl512, let artURL = URL(string: url) {
                    AsyncImage(url: artURL) { phase in
                        if let img = phase.image { img.resizable().scaledToFit() }
                        else { Color.secondary.opacity(0.15) }
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.trackName).fontWeight(.medium).lineLimit(1)
                    Text(app.artistName).font(.caption).foregroundStyle(.secondary)
                    if let rating = app.averageUserRating, let count = app.userRatingCount {
                        Text(loc(.mktRatingFmt, rating, count))
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                if let price = app.formattedPrice {
                    Text(price).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared detail view

struct ITunesAppDetailView: View {
    @EnvironmentObject var loc: LocalizationManager
    let app: ITunesAppResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    if let url = app.artworkUrl512, let artURL = URL(string: url) {
                        AsyncImage(url: artURL) { phase in
                            if let img = phase.image { img.resizable().scaledToFit() }
                            else { Color.secondary.opacity(0.15) }
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.trackName).font(.title2).fontWeight(.semibold)
                        Text(app.artistName).foregroundStyle(.secondary)
                        if let rating = app.averageUserRating, let count = app.userRatingCount {
                            Text(loc(.mktRatingFmt, rating, count))
                        }
                        if let version = app.version {
                            Text("v\(version)").font(.caption).foregroundStyle(.tertiary)
                        }
                        if let bundle = app.bundleId {
                            Text(bundle).font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }

                if !app.screenshotUrls.isEmpty {
                    Text(loc(.mktScreenshots)).font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(app.screenshotUrls, id: \.self) { url in
                                if let imgURL = URL(string: url) {
                                    AsyncImage(url: imgURL) { phase in
                                        if let img = phase.image {
                                            img.resizable().scaledToFit()
                                        } else {
                                            Color.secondary.opacity(0.1)
                                        }
                                    }
                                    .frame(height: 280)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                }

                if let desc = app.description, !desc.isEmpty {
                    Text(loc(.mktDescription)).font(.headline)
                    Text(desc).font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
