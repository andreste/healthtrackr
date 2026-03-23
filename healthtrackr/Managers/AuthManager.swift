import AuthenticationServices
import SwiftUI

@MainActor @Observable
final class AuthManager {
    var isAuthenticated = false
    var isCheckingCredential = true

    private static let userIDKey = "appleUserIdentifier"

    // MARK: - Lifecycle

    func checkExistingCredential() async {
        guard let userIDData = KeychainHelper.read(key: Self.userIDKey),
              let userID = String(data: userIDData, encoding: .utf8) else {
            isCheckingCredential = false
            return
        }

        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await provider.credentialState(forUserID: userID)
            switch state {
            case .authorized:
                isAuthenticated = true
            case .revoked, .notFound:
                clearCredentials()
            default:
                clearCredentials()
            }
        } catch {
            clearCredentials()
        }
        isCheckingCredential = false
    }

    // MARK: - Sign In

    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return
            }
            let userID = credential.user

            let savedUserID = KeychainHelper.save(key: Self.userIDKey, data: Data(userID.utf8))
            #if DEBUG
            if !savedUserID {
                print("[AuthManager] Failed to save user ID to Keychain")
            }
            #endif

            isAuthenticated = true

        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            #if DEBUG
            print("[AuthManager] Sign in with Apple failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Sign Out

    func signOut() {
        clearCredentials()
    }

    private func clearCredentials() {
        KeychainHelper.delete(key: Self.userIDKey)
        isAuthenticated = false
    }
}
