import SwiftUI

struct HealthMetricsView: View {
    let analytics: any AnalyticsProviding
    @State private var viewModel: HealthMetricsViewModel

    init(healthKit: (any HealthKitProviding)? = nil, analytics: (any AnalyticsProviding)? = nil) {
        self.analytics = analytics ?? MixpanelAnalyticsService()
        if let healthKit {
            self._viewModel = State(initialValue: HealthMetricsViewModel(healthKit: healthKit))
        } else {
            self._viewModel = State(initialValue: HealthMetricsViewModel())
        }
    }

    // MARK: - Section definitions (order matches ViewModel config)

    private static var sections: [(title: String, ids: [String])] {
        [
            (String(localized: "Recovery", bundle: Bundle.localization), ["sleep", "hrv", "spo2", "respiratoryRate"]),
            (String(localized: "Activity", bundle: Bundle.localization), ["steps", "activeEnergy", "exerciseTime", "distance"]),
            (String(localized: "Fitness", bundle: Bundle.localization),  ["rhr", "walkingHR", "vo2Max", "bodyMass"]),
        ]
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
                    .tint(Color("accentPrimary"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .healthKitDenied:
                healthKitDeniedView

            case .loaded:
                metricsContent
            }
        }
        .background(Color("bgPrimary"))
        .navigationTitle("Health Data")
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.load() }
        .onAppear {
            analytics.track(event: .healthMetricsViewed)
        }
    }

    // MARK: - Metrics content

    private var metricsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space6) {
                Text("Last 7 days from Apple Health")
                    .font(Typography.bodySM)
                    .foregroundStyle(Color("textTertiary"))
                    .padding(.horizontal, Spacing.screenHorizontalMargin)
                    .padding(.top, Spacing.space2)

                ForEach(Self.sections, id: \.title) { section in
                    sectionBlock(title: section.title, ids: section.ids)
                }
            }
            .padding(.bottom, Spacing.space7)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Section block

    private func sectionBlock(title: String, ids: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.space3) {
            Text(title.uppercased())
                .font(Typography.dataXS)
                .tracking(Typography.Tracking.monoCaps * 10)
                .foregroundStyle(Color("textTertiary"))
                .padding(.horizontal, Spacing.screenHorizontalMargin)

            VStack(spacing: 0) {
                let snapshots = ids.compactMap { id in viewModel.snapshots.first { $0.id == id } }
                ForEach(Array(snapshots.enumerated()), id: \.element.id) { index, snapshot in
                    metricRow(snapshot)

                    if index < snapshots.count - 1 {
                        Divider()
                            .background(Color("borderDefault"))
                            .padding(.leading, Spacing.screenHorizontalMargin)
                    }
                }
            }
            .background(Color("bgCard"))
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color("borderDefault"), lineWidth: 1)
            )
            .padding(.horizontal, Spacing.screenHorizontalMargin)
        }
    }

    // MARK: - Metric row

    private func metricRow(_ snapshot: MetricSnapshot) -> some View {
        HStack(alignment: .center, spacing: Spacing.space4) {
            // Label
            Text(snapshot.label)
                .font(Typography.bodyMD)
                .foregroundStyle(Color("textPrimary"))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Value block
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: Spacing.space1) {
                    Text(HealthMetricsFormatter.formatValue(snapshot))
                        .font(Typography.dataMD)
                        .foregroundStyle(
                            snapshot.latestValue != nil
                                ? Color("textPrimary")
                                : Color("textTertiary")
                        )

                    if snapshot.latestValue != nil {
                        Text(snapshot.unit)
                            .font(Typography.dataXS)
                            .foregroundStyle(Color("textTertiary"))
                    }
                }

                if let avg = snapshot.weeklyAverage {
                    Text("avg \(HealthMetricsFormatter.formatValue(snapshot, using: avg))")
                        .font(Typography.dataXS)
                        .foregroundStyle(Color("textTertiary"))
                }
            }

            // Recency badge
            if let date = snapshot.latestDate {
                Text(HealthMetricsFormatter.formatRecency(date))
                    .font(Typography.dataXS)
                    .foregroundStyle(Color("textTertiary"))
                    .frame(width: 52, alignment: .trailing)
            }
        }
        .padding(.horizontal, Spacing.screenHorizontalMargin)
        .padding(.vertical, Spacing.statRowPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(HealthMetricsFormatter.accessibilityLabel(snapshot))
    }

    // MARK: - HealthKit Denied

    private var healthKitDeniedView: some View {
        VStack(spacing: Spacing.space4) {
            Image(systemName: "heart.slash")
                .font(.system(size: 40))
                .foregroundStyle(Color("semanticError"))

            Text("Health data access required")
                .font(Typography.bodyMD)
                .foregroundStyle(Color("textPrimary"))

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(Typography.labelMD)
                    .foregroundStyle(Color("accentPrimary"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("Health Metrics") {
    NavigationStack {
        HealthMetricsView()
    }
}

#Preview("Health Metrics - Dark") {
    NavigationStack {
        HealthMetricsView()
    }
    .preferredColorScheme(.dark)
}
