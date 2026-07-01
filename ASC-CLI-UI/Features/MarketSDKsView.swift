import SwiftUI
import ASCShared

struct MarketSDKsView: View {
    @EnvironmentObject var loc: LocalizationManager
    @EnvironmentObject var market: MarketEngine

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.secMarketSDKs), subtitle: nil) {
                Button { Task { await market.refreshCharts() } } label: {
                    Label(loc(.mktRefresh), systemImage: "arrow.clockwise")
                }
                .disabled(market.isLoading)
            }
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(loc(.mktSDKsBody)).font(.callout).foregroundStyle(.secondary)
                    Text(loc(.mktSDKDisclaimer)).font(.caption).foregroundStyle(.tertiary)

                    sdkCatalog

                    let matches = market.sdkMatches()
                    if matches.isEmpty {
                        if market.feed == nil {
                            ProgressView(loc(.mktLoading))
                        } else {
                            ContentUnavailableView(
                                loc(.mktSDKMatches),
                                systemImage: "puzzlepiece.extension",
                                description: Text(loc(.mktNotInChart))
                            )
                        }
                    } else {
                        matchesSection(matches)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task {
            if market.feed == nil { await market.refreshCharts() }
        }
    }

    private var sdkCatalog: some View {
        GroupBox {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
                ForEach(KnownSDKCatalog.all) { sdk in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sdk.name).fontWeight(.medium)
                        Text(sdk.vendor).font(.caption).foregroundStyle(.secondary)
                        Text(sdk.category).font(.caption2).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(4)
        } label: {
            Label("SDKs", systemImage: "puzzlepiece.extension")
        }
    }

    private func matchesSection(_ matches: [SDKChartMatch]) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(matches) { match in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(match.sdk.name).fontWeight(.medium)
                            Text(match.app.name).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(loc(.mktRankFmt, match.app.rank))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(4)
        } label: {
            Label(loc(.mktSDKMatches), systemImage: "link")
        }
    }
}
