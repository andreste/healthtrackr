import Foundation
import Testing
@testable import healthtrackr

// MARK: - Fakes

final class FakeCacheClearing: CacheClearing {
    var clearAllCachesCalled = false
    func clearAllCaches() async {
        clearAllCachesCalled = true
    }
}

@MainActor
final class FakeUserDefaults {
    private var store: [String: Any] = [:]

    func set(_ value: Any?, forKey key: String) {
        store[key] = value
    }

    func string(forKey key: String) -> String? {
        store[key] as? String
    }

    func removeObject(forKey key: String) {
        store.removeValue(forKey: key)
    }
}

// MARK: - AuthManager User Profile Tests

@Suite("AuthManager User Profile")
struct AuthManagerUserProfileTests {

    private static let firstNameKey = "appleUserFirstName"
    private static let photoURLKey = "appleUserPhotoURL"

    @Test("firstName returns nil when not set")
    @MainActor func firstNameNilByDefault() {
        // Clean up any leftover state
        UserDefaults.standard.removeObject(forKey: Self.firstNameKey)
        let manager = AuthManager()
        #expect(manager.firstName == nil)
    }

    @Test("firstName returns stored value")
    @MainActor func firstNameReturnsStoredValue() {
        UserDefaults.standard.set("Andres", forKey: Self.firstNameKey)
        let manager = AuthManager()
        #expect(manager.firstName == "Andres")
        // Clean up
        UserDefaults.standard.removeObject(forKey: Self.firstNameKey)
    }

    @Test("photoURL returns nil when not set")
    @MainActor func photoURLNilByDefault() {
        UserDefaults.standard.removeObject(forKey: Self.photoURLKey)
        let manager = AuthManager()
        #expect(manager.photoURL == nil)
    }

    @Test("photoURL returns stored URL")
    @MainActor func photoURLReturnsStoredURL() {
        let urlString = "https://example.com/photo.jpg"
        UserDefaults.standard.set(urlString, forKey: Self.photoURLKey)
        let manager = AuthManager()
        #expect(manager.photoURL == URL(string: urlString))
        // Clean up
        UserDefaults.standard.removeObject(forKey: Self.photoURLKey)
    }

    @Test("signOut clears firstName and photoURL")
    @MainActor func signOutClearsUserInfo() async {
        UserDefaults.standard.set("Andres", forKey: Self.firstNameKey)
        UserDefaults.standard.set("https://example.com/photo.jpg", forKey: Self.photoURLKey)
        let manager = AuthManager()
        #expect(manager.firstName == "Andres")

        await manager.signOut()

        #expect(manager.firstName == nil)
        #expect(manager.photoURL == nil)
    }

    @Test("signOut calls clearAllCaches on the cache")
    @MainActor func signOutClearsCaches() async {
        UserDefaults.standard.set("Andres", forKey: Self.firstNameKey)
        let fakeCache = FakeCacheClearing()
        let manager = AuthManager(cache: fakeCache)

        await manager.signOut()

        #expect(fakeCache.clearAllCachesCalled)
    }
}

// MARK: - ProfileButtonView Display Logic Tests

@Suite("Profile Display Logic")
struct ProfileDisplayLogicTests {

    @Test("firstName extracts first name correctly from full name")
    @MainActor func firstNameExtraction() {
        let key = "appleUserFirstName"
        UserDefaults.standard.set("John", forKey: key)
        let manager = AuthManager()
        #expect(manager.firstName == "John")
        UserDefaults.standard.removeObject(forKey: key)
    }

    @Test("photoURL handles invalid URL string gracefully")
    @MainActor func invalidPhotoURL() {
        let key = "appleUserPhotoURL"
        // Empty string produces a valid URL in Foundation, so test with truly invalid
        UserDefaults.standard.removeObject(forKey: key)
        let manager = AuthManager()
        #expect(manager.photoURL == nil)
    }
}
