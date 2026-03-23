import SwiftUI

struct DataReadinessView: View {
    @State private var viewModel = DataReadinessViewModel()
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Product name + tagline
            VStack(spacing: Spacing.space2) {
                Text("healthtrackr")
                    .font(Typography.displayXL)
                    .tracking(Typography.Tracking.display * 42)
                    .foregroundStyle(Color("textPrimary"))

                Text("Discover what your health data reveals")
                    .font(Typography.displayItalic)
                    .foregroundStyle(Color("textSecondary"))
            }
            .padding(.bottom, Spacing.space7)

            // Data readiness checklist
            VStack(spacing: Spacing.space3) {
                switch viewModel.state {
                case .loading:
                    ProgressView()
                        .tint(Color("accentPrimary"))
                        .padding(.vertical, Spacing.space6)

                case .healthKitDenied:
                    healthKitDeniedRow

                case .loaded:
                    ForEach(viewModel.metricStatuses) { status in
                        metricRow(status)
                    }
                }
            }
            .padding(Spacing.cardInternalPadding)
            .background(Color("bgCard"))
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color("borderDefault"), lineWidth: 1)
            )
            .padding(.horizontal, Spacing.screenHorizontalMargin)

            Spacer()

            // CTA + privacy note
            VStack(spacing: Spacing.space3) {
                Button {
                    onStart()
                } label: {
                    Text("Start finding patterns")
                        .font(Typography.labelMD)
                        .foregroundStyle(Color("textOnAccent"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(viewModel.canStart ? Color("accentPrimary") : Color("borderDefault"))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                }
                .disabled(!viewModel.canStart)
                .padding(.horizontal, Spacing.screenHorizontalMargin)

                Text("Analysis runs on your device. Only pattern summaries are sent to AI.")
                    .font(Typography.bodySM)
                    .foregroundStyle(Color("textTertiary"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.screenHorizontalMargin)
            }
            .padding(.bottom, Spacing.space7)
        }
        .background(Color("bgPrimary"))
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Metric Row

    private func metricRow(_ status: DataReadinessViewModel.MetricStatus) -> some View {
        HStack {
            Text(status.label)
                .font(Typography.bodyMD)
                .foregroundStyle(Color("textPrimary"))

            Spacer()

            if status.isReady {
                HStack(spacing: Spacing.space1) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color("semanticSuccess"))
                        .font(.system(size: 16))
                    Text("\(status.daysAvailable) days")
                        .font(Typography.dataSM)
                        .foregroundStyle(Color("semanticSuccess"))
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Need more data")
                        .font(Typography.dataSM)
                        .foregroundStyle(Color("textTertiary"))
                    Text("check back in \(status.daysUntilReady) days")
                        .font(Typography.dataSM)
                        .foregroundStyle(Color("textTertiary"))
                }
            }
        }
        .padding(.vertical, Spacing.space2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            status.isReady
                ? "\(status.label): ready, \(status.daysAvailable) days available"
                : "\(status.label): need more data, check back in \(status.daysUntilReady) days"
        )
    }

    // MARK: - HealthKit Denied

    private var healthKitDeniedRow: some View {
        VStack(spacing: Spacing.space3) {
            Image(systemName: "heart.slash")
                .font(.system(size: 32))
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
        .padding(.vertical, Spacing.space4)
    }
}

// MARK: - Previews

#Preview("Data Readiness - Ready") {
    DataReadinessView { }
}

#Preview("Data Readiness - Dark") {
    DataReadinessView { }
        .preferredColorScheme(.dark)
}
