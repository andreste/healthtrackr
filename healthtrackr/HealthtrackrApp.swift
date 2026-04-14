import SwiftUI
#if canImport(Mixpanel)
import Mixpanel
#endif

@main
struct HealthtrackrApp: App {
    @State private var authManager: AuthManager
    @State private var engine: CorrelationEngine
    @State private var narrator: PatternNarrator
    private let analytics: any AnalyticsProviding = MixpanelAnalyticsService()

    init() {
        #if canImport(Mixpanel)
        Mixpanel.initialize(token: AppConfig.mixpanelToken ?? "", trackAutomaticEvents: false)
        #endif
        let cache = CacheActor()
        let auth = AuthManager(cache: cache)
        #if DEBUG
        if UITestArgument.skipAuth {
            auth.isAuthenticated = true
        }
        #endif
        _authManager = State(initialValue: auth)
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
                ContentView(authManager: authManager, engine: engine, narrator: narrator, analytics: analytics)
                    .transition(.opacity)
                    .onAppear {
                        analytics.track(event: .signedIn)
                        if let userId = authManager.userId {
                            var props: [String: String] = ["Platform": "iOS"]
                            if let name = authManager.firstName { props["$name"] = name }
                            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                                props["App Version"] = version
                            }
                            analytics.identify(userId: userId, properties: props)
                        }
                    }
            } else {
                SignInView(authManager: authManager, analytics: analytics)
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
                if authManager.isAuthenticated {
                    ContentView(
                        authManager: authManager,
                        skipOnboarding: !UITestArgument.showHealthKitPermissions,
                        healthKit: StubHealthKit(denied: UITestArgument.healthKitDenied),
                        engine: StubCorrelationEngine(empty: UITestArgument.stubEmptyFeed),
                        narrator: StubNarrator()
                    )
                } else {
                    SignInView(authManager: authManager)
                }
            } else {
                SignInView(authManager: authManager)
            }
        }
    }
    #endif
}
