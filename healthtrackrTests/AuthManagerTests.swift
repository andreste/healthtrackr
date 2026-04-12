import Foundation
import Testing
@testable import healthtrackr

// MARK: - Fakes

final class FakeCacheClearing: CacheInvalidating {
    nonisolated(unsafe) var clearAllCachesCalled = false
    func clearAllCaches() async {
        clearAllCachesCalled = true
    }
}

// MARK: - Helpers

private let firstNameKey = "appleUserFirstName"
private let photoURLKey = "appleUserPhotoURL"

private func cleanKeychain() {
    KeychainHelper.delete(key: firstNameKey)
    KeychainHelper.delete(key: photoURLKey)
}

// MARK: - AuthManager User Profile Tests

@Suite("AuthManager User Profile")
struct AuthManagerUserProfileTests {

    @Test("firstName returns nil when not set")
    @MainActor func firstNameNilByDefault() {
        cleanKeychain()
        let manager = AuthManager()
        #expect(manager.firstName == nil)
    }

    @Test("firstName returns stored value")
    @MainActor func firstNameReturnsStoredValue() {
        cleanKeychain()
        KeychainHelper.save(key: firstNameKey, data: Data("Andres".utf8))
        let manager = AuthManager()
        #expect(manager.firstName == "Andres")
        cleanKeychain()
    }

    @Test("photoURL returns nil when not set")
    @MainActor func photoURLNilByDefault() {
        cleanKeychain()
        let manager = AuthManager()
        #expect(manager.photoURL == nil)
    }

    @Test("photoURL returns stored URL")
    @MainActor func photoURLReturnsStoredURL() {
        cleanKeychain()
        let urlString = "https://example.com/photo.jpg"
        KeychainHelper.save(key: photoURLKey, data: Data(urlString.utf8))
        let manager = AuthManager()
        #expect(manager.photoURL == URL(string: urlString))
        cleanKeychain()
    }

    @Test("signOut clears firstName and photoURL from Keychain")
    @MainActor func signOutClearsUserInfo() async {
        cleanKeychain()
        KeychainHelper.save(key: firstNameKey, data: Data("Andres".utf8))
        KeychainHelper.save(key: photoURLKey, data: Data("https://example.com/photo.jpg".utf8))
        let manager = AuthManager()
        #expect(manager.firstName == "Andres")

        await manager.signOut()

        #expect(manager.firstName == nil)
        #expect(manager.photoURL == nil)
    }

    @Test("signOut calls clearAllCaches on the cache")
    @MainActor func signOutClearsCaches() async {
        cleanKeychain()
        KeychainHelper.save(key: firstNameKey, data: Data("Andres".utf8))
        let fakeCache = FakeCacheClearing()
        let manager = AuthManager(cache: fakeCache)

        await manager.signOut()

        #expect(fakeCache.clearAllCachesCalled)
    }
}

// MARK: - UserDefaults → Keychain Migration Tests

@Suite("AuthManager Migration")
struct AuthManagerMigrationTests {

    @Test("firstName migrates from UserDefaults to Keychain on init")
    @MainActor func migratesFirstNameFromUserDefaults() {
        cleanKeychain()
        UserDefaults.standard.set("MigratedName", forKey: firstNameKey)

        let manager = AuthManager()

        // After init, value should be in Keychain and removed from UserDefaults
        #expect(manager.firstName == "MigratedName")
        #expect(UserDefaults.standard.string(forKey: firstNameKey) == nil)
        cleanKeychain()
    }

    @Test("photoURL migrates from UserDefaults to Keychain on init")
    @MainActor func migratesPhotoURLFromUserDefaults() {
        cleanKeychain()
        let urlString = "https://example.com/migrated.jpg"
        UserDefaults.standard.set(urlString, forKey: photoURLKey)

        let manager = AuthManager()

        #expect(manager.photoURL == URL(string: urlString))
        #expect(UserDefaults.standard.string(forKey: photoURLKey) == nil)
        cleanKeychain()
    }

    @Test("migration does not overwrite existing Keychain value when UserDefaults is empty")
    @MainActor func doesNotOverwriteExistingKeychain() {
        cleanKeychain()
        KeychainHelper.save(key: firstNameKey, data: Data("ExistingName".utf8))
        UserDefaults.standard.removeObject(forKey: firstNameKey)

        let manager = AuthManager()

        // Keychain value should be preserved
        #expect(manager.firstName == "ExistingName")
        cleanKeychain()
    }
}

// MARK: - ProfileButtonView Display Logic Tests

@Suite("Profile Display Logic")
struct ProfileDisplayLogicTests {

    @Test("firstName reads from Keychain correctly")
    @MainActor func firstNameExtraction() {
        cleanKeychain()
        KeychainHelper.save(key: firstNameKey, data: Data("John".utf8))
        let manager = AuthManager()
        #expect(manager.firstName == "John")
        cleanKeychain()
    }

    @Test("photoURL returns nil when Keychain has no entry")
    @MainActor func photoURLNilWhenMissing() {
        cleanKeychain()
        let manager = AuthManager()
        #expect(manager.photoURL == nil)
    }
}
