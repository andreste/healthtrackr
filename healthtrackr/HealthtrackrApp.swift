import SwiftUI

@main
struct HealthtrackrApp: App {
    @State private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if UITestArgument.isUITesting {
                    uiTestingRoot
                } else {
                    productionRoot
                }
                #else
                productionRoot
                #endif
            }
            .animation(.easeOut(duration: AnimationDuration.medium), value: authManager.isAuthenticated)
            .animation(.easeOut(duration: AnimationDuration.medium), value: authManager.isCheckingCredential)
        }
    }

    private var productionRoot: some View {
        Group {
            if authManager.isCheckingCredential {
                Color("bgPrimary")
                    .ignoresSafeArea()
            } else if authManager.isAuthenticated {
                ContentView(authManager: authManager)
                    .transition(.opacity)
            } else {
                SignInView(authManager: authManager)
                    .transition(.opacity)
            }
        }
        .task {
            await authManager.checkExistingCredential()
        }
    }

    #if DEBUG
    private var uiTestingRoot: some View {
        Group {
            if UITestArgument.skipAuth {
                ContentView(
                    authManager: authManager,
                    skipOnboarding: true,
                    healthKit: StubHealthKit(denied: UITestArgument.healthKitDenied),
                    engine: StubCorrelationEngine(empty: UITestArgument.stubEmptyFeed),
                    narrator: StubNarrator()
                )
            } else {
                SignInView(authManager: authManager)
            }
        }
    }
    #endif
}
