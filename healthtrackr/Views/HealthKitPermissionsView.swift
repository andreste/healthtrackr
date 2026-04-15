import SwiftUI

struct HealthKitPermissionsView: View {
    let healthKit: any HealthKitProviding
    let analytics: any AnalyticsProviding
    let onGranted: () -> Void

    @State private var isRequesting = false
    @State private var authorizationError: Error?

    init(
        healthKit: any HealthKitProviding,
        analytics: (any AnalyticsProviding)? = nil,
        onGranted: @escaping () -> Void
    ) {
        self.healthKit = healthKit
        self.analytics = analytics ?? MixpanelAnalyticsService()
        self.onGranted = onGranted
    }

    private static var categories: [(title: String, icon: String, metrics: [String])] {
        [
            (
                String(localized: "Recovery", bundle: .localization),
                "bed.double.fill",
                [
                    String(localized: "Sleep duration", bundle: .localization),
                    String(localized: "HRV", bundle: .localization),
                    String(localized: "Blood oxygen", bundle: .localization),
                    String(localized: "Respiratory rate", bundle: .localization),
                ]
            ),
            (
                String(localized: "Activity", bundle: .localization),
                "figure.walk",
                [
                    String(localized: "Steps", bundle: .localization),
                    String(localized: "Active energy", bundle: .localization),
                    String(localized: "Exercise time", bundle: .localization),
                    String(localized: "Distance (km)", bundle: .localization),
                ]
            ),
            (
                String(localized: "Fitness", bundle: .localization),
                "heart.fill",
                [
                    String(localized: "Resting heart rate", bundle: .localization),
                    String(localized: "Walking heart rate", bundle: .localization),
                    String(localized: "VO2 Max (mL/kg/min)", bundle: .localization),
                    String(localized: "Body mass", bundle: .localization),
                ]
            ),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

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

            VStack(spacing: Spacing.space3) {
                ForEach(Self.categories, id: \.title) { category in
                    categoryRow(category)
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

            VStack(spacing: Spacing.space3) {
                Button {
                    isRequesting = true
                    authorizationError = nil
                    analytics.track(event: .healthKitPermissionRequested)
                } label: {
                    Group {
                        if isRequesting {
                            ProgressView()
                                .tint(Color("textOnAccent"))
                        } else {
                            Text("Grant Access")
                                .font(Typography.labelMD)
                                .foregroundStyle(Color("textOnAccent"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color("accentPrimary"))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                }
                .disabled(isRequesting)
                .accessibilityIdentifier("GrantHealthKitAccessButton")
                .padding(.horizontal, Spacing.screenHorizontalMargin)

                Text("Your health data stays on your device. Only anonymous pattern summaries are sent to AI.")
                    .font(Typography.bodySM)
                    .foregroundStyle(Color("textTertiary"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.screenHorizontalMargin)
            }
            .padding(.bottom, Spacing.space7)
        }
        .background(Color("bgPrimary"))
        .accessibilityIdentifier("HealthKitPermissionsView")
        .task(id: isRequesting) {
            guard isRequesting else { return }
            do {
                try await healthKit.requestAuthorization()
                UserDefaults.standard.set(true, forKey: "hasGrantedHealthKitPermission")
                onGranted()
            } catch {
                authorizationError = error
                isRequesting = false
            }
        }
        .onAppear {
            analytics.track(event: .healthKitPermissionsViewed)
        }
    }

    private func categoryRow(_ category: (title: String, icon: String, metrics: [String])) -> some View {
        HStack(alignment: .top, spacing: Spacing.space3) {
            Image(systemName: category.icon)
                .font(.system(size: 16))
                .foregroundStyle(Color("accentPrimary"))
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: Spacing.space1) {
                Text(category.title.uppercased())
                    .font(Typography.dataXS)
                    .tracking(Typography.Tracking.monoCaps * 10)
                    .foregroundStyle(Color("textTertiary"))

                Text(category.metrics.joined(separator: ", "))
                    .font(Typography.bodyMD)
                    .foregroundStyle(Color("textSecondary"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.space2)
    }
}

#Preview("Permissions") {
    HealthKitPermissionsView(healthKit: HealthKitManager(), onGranted: {})
}

#Preview("Permissions - Dark") {
    HealthKitPermissionsView(healthKit: HealthKitManager(), onGranted: {})
        .preferredColorScheme(.dark)
}
