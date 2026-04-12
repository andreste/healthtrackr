import SwiftUI

@main
struct HealthtrackrApp: App {
    @State private var authManager: AuthManager
    @State private var engine: CorrelationEngine
    @State private var narrator: PatternNarrator

    init() {
        let cache = CacheActor()
        _authManager = State(initialValue: AuthManager(cache: cache))
        _engine = State(initialValue: CorrelationEngine(cache: cache))
        _narrator = State(initialValue: PatternNarrator(cache: cache))
    }

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
                ContentView(authManager: authManager, engine: engine, narrator: narrator)
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
