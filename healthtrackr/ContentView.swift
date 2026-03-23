import SwiftUI

struct ContentView: View {
    let authManager: AuthManager

    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedDataReadiness")

    var body: some View {
        if hasCompletedOnboarding {
            DiscoveryFeedView(authManager: authManager)
                .transition(.opacity)
        } else {
            DataReadinessView {
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
