import AuthenticationServices
import SwiftUI

@Observable
final class AuthManager {
    var isAuthenticated = false
    var isCheckingCredential = true

    private static let userIDKey = "appleUserIdentifier"
    private static let tokenKey = "appleIdentityToken"

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
            KeychainHelper.save(key: Self.userIDKey, data: Data(userID.utf8))
            if let tokenData = credential.identityToken {
                KeychainHelper.save(key: Self.tokenKey, data: tokenData)
            }
            isAuthenticated = true

        case .failure(let error):
            guard let authError = error as? ASAuthorizationError,
                  authError.code != .canceled else {
                return
            }
            print("Sign in with Apple failed: \(authError.localizedDescription)")
        }
    }

    // MARK: - Sign Out

    func signOut() {
        clearCredentials()
    }

    private func clearCredentials() {
        KeychainHelper.delete(key: Self.userIDKey)
        KeychainHelper.delete(key: Self.tokenKey)
        isAuthenticated = false
    }
}
