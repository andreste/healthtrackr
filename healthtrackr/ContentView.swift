import SwiftUI

struct ContentView: View {
    let authManager: AuthManager
    let healthKit: (any HealthKitProviding)?
    let engine: (any CorrelationProviding)?
    let narrator: (any NarrationProviding)?
    let analytics: any AnalyticsProviding

    @State private var hasCompletedOnboarding: Bool
    @State private var hasGrantedHealthKit: Bool

    init(
        authManager: AuthManager,
        skipOnboarding: Bool = false,
        healthKit: (any HealthKitProviding)? = nil,
        engine: (any CorrelationProviding)? = nil,
        narrator: (any NarrationProviding)? = nil,
        analytics: (any AnalyticsProviding)? = nil
    ) {
        self.authManager = authManager
        self.healthKit = healthKit
        self.engine = engine
        self.narrator = narrator
        self.analytics = analytics ?? MixpanelAnalyticsService()
        let onboarded = skipOnboarding || UserDefaults.standard.bool(forKey: "hasCompletedDataReadiness")
        self._hasCompletedOnboarding = State(initialValue: onboarded)
        self._hasGrantedHealthKit = State(
            initialValue: onboarded || UserDefaults.standard.bool(forKey: "hasGrantedHealthKitPermission")
        )
    }

    var body: some View {
        Group {
            content
        }
        .task {
            guard !hasGrantedHealthKit else { return }
            let hk: any HealthKitProviding = healthKit ?? HealthKitManager()
            if await hk.isAlreadyAuthorized {
                UserDefaults.standard.set(true, forKey: "hasGrantedHealthKitPermission")
                hasGrantedHealthKit = true
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if hasCompletedOnboarding {
            DiscoveryFeedView(
                authManager: authManager,
                healthKit: healthKit,
                engine: engine,
                narrator: narrator,
                analytics: analytics
            )
            .transition(.opacity)
        } else {
            HealthKitPermissionsView(
                healthKit: healthKit ?? HealthKitManager(),
                analytics: analytics,
                onGranted: {
                    UserDefaults.standard.set(true, forKey: "hasGrantedHealthKitPermission")
                    UserDefaults.standard.set(true, forKey: "hasCompletedDataReadiness")
                    analytics.track(event: .healthKitPermissionGranted)
                    analytics.track(event: .onboardingCompleted)
                    withAnimation(.easeOut(duration: AnimationDuration.medium)) {
                        hasGrantedHealthKit = true
                        hasCompletedOnboarding = true
                    }
                }
            )
            .transition(.opacity)
        }
    }
}

#Preview {
    ContentView(authManager: AuthManager())
}
