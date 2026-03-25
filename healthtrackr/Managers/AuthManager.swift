import AuthenticationServices
import SwiftUI

@MainActor @Observable
final class AuthManager {
    var isAuthenticated = false
    var isCheckingCredential = true

    private static let userIDKey = "appleUserIdentifier"
    private static let userFirstNameKey = "appleUserFirstName"
    private static let userPhotoURLKey = "appleUserPhotoURL"

    var firstName: String? {
        UserDefaults.standard.string(forKey: Self.userFirstNameKey)
    }

    var photoURL: URL? {
        guard let urlString = UserDefaults.standard.string(forKey: Self.userPhotoURLKey) else {
            return nil
        }
        return URL(string: urlString)
    }

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

            // Apple only provides the name on the first sign-in — persist it
            if let givenName = credential.fullName?.givenName, !givenName.isEmpty {
                UserDefaults.standard.set(givenName, forKey: Self.userFirstNameKey)
            }

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
        UserDefaults.standard.removeObject(forKey: Self.userFirstNameKey)
        UserDefaults.standard.removeObject(forKey: Self.userPhotoURLKey)
        isAuthenticated = false
    }
}
