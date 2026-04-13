import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Bindable var authManager: AuthManager
    let analytics: any AnalyticsProviding
    @Environment(\.colorScheme) private var colorScheme

    init(authManager: AuthManager, analytics: (any AnalyticsProviding)? = nil) {
        self.authManager = authManager
        self.analytics = analytics ?? MixpanelAnalyticsService()
    }

    var body: some View {
        VStack(spacing: Spacing.space6) {
            Spacer()

            VStack(spacing: Spacing.space3) {
                Text("healthtrackr")
                    .font(Typography.displayLG)
                    .tracking(Typography.Tracking.display)
                    .foregroundStyle(Color("textPrimary"))

                Text("Find patterns in your health data you wouldn't notice on your own.")
                    .font(Typography.bodyLG)
                    .foregroundStyle(Color("textSecondary"))
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Find patterns in your health data you wouldn't notice on your own.")

                Text("Your health data never leaves your device.")
                    .font(Typography.bodySM)
                    .foregroundStyle(Color("textTertiary"))
            }
            .padding(.horizontal, Spacing.screenHorizontalMargin)

            Spacer()

            VStack(spacing: Spacing.space4) {
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                        analytics.track(event: .signInTapped)
                    },
                    onCompletion: { result in
                        MainActor.assumeIsolated {
                            if case .failure(let error) = result {
                                if let authError = error as? ASAuthorizationError,
                                   authError.code == .canceled {
                                    // Ignore cancellations — not a failure worth tracking
                                } else {
                                    analytics.track(event: .signInFailed(reason: error.localizedDescription))
                                }
                            }
                            authManager.handleSignInResult(result)
                        }
                    }
                )
                .signInWithAppleButtonStyle(
                    colorScheme == .dark ? .white : .black
                )
                .frame(height: 50)
                .cornerRadius(Radius.sm)

                Text("By continuing, you agree to our Privacy Policy.")
                    .font(Typography.labelSM)
                    .foregroundStyle(Color("textTertiary"))
            }
            .padding(.horizontal, Spacing.screenHorizontalMargin)
            .padding(.bottom, Spacing.space7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("bgPrimary"))
        .accessibilityIdentifier("SignInView")
        .onAppear {
            analytics.track(event: .signInViewed)
        }
    }
}

#Preview("Light") {
    SignInView(authManager: AuthManager())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    SignInView(authManager: AuthManager())
        .preferredColorScheme(.dark)
}
