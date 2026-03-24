import SwiftUI

struct ContentView: View {
    let authManager: AuthManager
    let healthKit: (any HealthKitProviding)?
    let engine: (any CorrelationProviding)?
    let narrator: (any NarrationProviding)?

    @State private var hasCompletedOnboarding: Bool

    init(
        authManager: AuthManager,
        skipOnboarding: Bool = false,
        healthKit: (any HealthKitProviding)? = nil,
        engine: (any CorrelationProviding)? = nil,
        narrator: (any NarrationProviding)? = nil
    ) {
        self.authManager = authManager
        self.healthKit = healthKit
        self.engine = engine
        self.narrator = narrator
        self._hasCompletedOnboarding = State(
            initialValue: skipOnboarding || UserDefaults.standard.bool(forKey: "hasCompletedDataReadiness")
        )
    }

    var body: some View {
        if hasCompletedOnboarding {
            DiscoveryFeedView(
                authManager: authManager,
                healthKit: healthKit,
                engine: engine,
                narrator: narrator
            )
            .transition(.opacity)
        } else {
            DataReadinessView(healthKit: healthKit) {
                UserDefaults.standard.set(true, forKey: "hasCompletedDataReadiness")
                withAnimation(.easeOut(duration: AnimationDuration.medium)) {
                    hasCompletedOnboarding = true
                }
            }
            .transition(.opacity)
        }
    }
}

#Preview {
    ContentView(authManager: AuthManager())
}
