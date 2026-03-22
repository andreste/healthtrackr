import SwiftUI

@main
struct HealthtrackrApp: App {
    @State private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isCheckingCredential {
                    Color("bgPrimary")
                        .ignoresSafeArea()
                } else if authManager.isAuthenticated {
                    ContentView()
                        .transition(.opacity)
                } else {
                    SignInView(authManager: authManager)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: Duration.medium), value: authManager.isAuthenticated)
            .animation(.easeOut(duration: Duration.medium), value: authManager.isCheckingCredential)
            .task {
                await authManager.checkExistingCredential()
            }
        }
    }
}
