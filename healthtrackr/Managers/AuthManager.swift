import AuthenticationServices
import SwiftUI

@MainActor @Observable
final class AuthManager {
    var isAuthenticated = false
    var isCheckingCredential = true

    private static let userIDKey = "appleUserIdentifier"
    private static let userFirstNameKey = "appleUserFirstName"
    private static let userPhotoURLKey = "appleUserPhotoURL"
    private static let hasLaunchedBeforeKey = "hasLaunchedBefore"

    private let cache: any CacheInvalidating

    convenience init() {
        self.init(cache: CacheActor())
    }

    init(cache: any CacheInvalidating) {
        self.cache = cache
        Self.migrateUserDefaultsToKeychain()
        Self.clearKeychainIfReinstalled()
    }

    /// Clears stale Keychain credentials left over from a previous install.
    /// UserDefaults is wiped on reinstall but Keychain is not — so if the
    /// "hasLaunchedBefore" flag is absent, this is a fresh install.
    private static func clearKeychainIfReinstalled() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: hasLaunchedBeforeKey) else { return }
        KeychainHelper.delete(key: userIDKey)
        KeychainHelper.delete(key: userFirstNameKey)
        KeychainHelper.delete(key: userPhotoURLKey)
        defaults.set(true, forKey: hasLaunchedBeforeKey)
    }

    var firstName: String? {
        guard let data = KeychainHelper.read(key: Self.userFirstNameKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    var photoURL: URL? {
        guard let data = KeychainHelper.read(key: Self.userPhotoURLKey),
              let urlString = String(data: data, encoding: .utf8) else { return nil }
        return URL(string: urlString)
    }

    // MARK: - UserDefaults → Keychain Migration

    private static func migrateUserDefaultsToKeychain() {
        let defaults = UserDefaults.standard
        if let name = defaults.string(forKey: userFirstNameKey) {
            KeychainHelper.save(key: userFirstNameKey, data: Data(name.utf8))
            defaults.removeObject(forKey: userFirstNameKey)
        }
        if let urlString = defaults.string(forKey: userPhotoURLKey) {
            KeychainHelper.save(key: userPhotoURLKey, data: Data(urlString.utf8))
            defaults.removeObject(forKey: userPhotoURLKey)
        }
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
                await clearCredentials()
            default:
                await clearCredentials()
            }
        } catch {
            await clearCredentials()
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
                KeychainHelper.save(key: Self.userFirstNameKey, data: Data(givenName.utf8))
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

    func signOut() async {
        await clearCredentials()
    }

    private func clearCredentials() async {
        KeychainHelper.delete(key: Self.userIDKey)
        KeychainHelper.delete(key: Self.userFirstNameKey)
        KeychainHelper.delete(key: Self.userPhotoURLKey)
        isAuthenticated = false
        await cache.clearAllCaches()
    }
}
