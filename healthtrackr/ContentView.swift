import SwiftUI

struct ContentView: View {
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedDataReadiness")

    var body: some View {
        if hasCompletedOnboarding {
            DiscoveryFeedView()
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
    ContentView()
}
