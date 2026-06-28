import SwiftUI
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

    @State private var stars = 0          // 0 == all
    @State private var territory = ""
    @State private var onlyUnresponded = false
    @State private var reviewId = ""
    @State private var responseText = ""

    var body: some View {
        CommandScreen(title: loc(.secReviews), subtitle: selectedApp?.name, intro: loc(.rvBody),
                      requireApp: true, hasApp: selectedApp != nil) { _, _ in
            VStack(alignment: .leading, spacing: 14) {
                CommandSection(title: loc(.rvReviews), systemImage: "text.bubble",
                               autoRun: { await ascService.reviewsList(appId: selectedApp?.id ?? "", stars: nil, territory: "", onlyUnresponded: false) },
                               autoRunToken: selectedApp?.id ?? "") { run, isRunning in
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
                            Button {
                                run { await ascService.reviewsList(appId: selectedApp?.id ?? "", stars: stars == 0 ? nil : stars,
                                                                   territory: territory, onlyUnresponded: onlyUnresponded) }
                            } label: { Label(loc(.actList), systemImage: "list.bullet") }
                            .disabled(isRunning)
                        }
                    }
                }

                CommandSection(title: loc(.rvRatings), systemImage: "star.leadinghalf.filled",
                               autoRun: { await ascService.reviewsRatings(appId: selectedApp?.id ?? "") },
                               autoRunToken: selectedApp?.id ?? "") { run, isRunning in
                    Button { run { await ascService.reviewsRatings(appId: selectedApp?.id ?? "") } } label: {
                        Label(loc(.refresh), systemImage: "arrow.clockwise")
                    }.disabled(isRunning)
                }

                CommandSection(title: loc(.rvRespond), systemImage: "arrowshape.turn.up.left") { run, isRunning in
                    VStack(alignment: .leading, spacing: 10) {
                        TextField(loc(.rvReviewId), text: $reviewId)
                            .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced))
                        TextField(loc(.rvResponseText), text: $responseText, axis: .vertical)
                            .textFieldStyle(.roundedBorder).lineLimit(3...6)
                        HStack {
                            Spacer()
                            Button {
                                run { await ascService.reviewRespond(reviewId: reviewId, text: responseText) }
                            } label: { Label(loc(.actRespond), systemImage: "arrowshape.turn.up.left") }
                            .buttonStyle(.borderedProminent)
                            .disabled(isRunning || reviewId.isEmpty || responseText.isEmpty)
                        }
                    }
                }
            }
        }
    }
}
