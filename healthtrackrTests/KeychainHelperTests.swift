import Foundation
import Testing
@testable import healthtrackr

// MARK: - KeychainHelper Tests

@Suite("KeychainHelper")
struct KeychainHelperTests {

    private let testKey = "com.healthtrackr.test.\(UUID().uuidString)"

    @Test("save and read round-trips data correctly")
    @MainActor func saveAndReadRoundTrip() {
        let data = Data("secret-token".utf8)
        let saved = KeychainHelper.save(key: testKey, data: data)
        #expect(saved == true)

        let result = KeychainHelper.read(key: testKey)
        #expect(result == data)

        KeychainHelper.delete(key: testKey)
    }

    @Test("read returns nil for missing key")
    @MainActor func readReturnsNilForMissingKey() {
        let result = KeychainHelper.read(key: "nonexistent-key-\(UUID().uuidString)")
        #expect(result == nil)
    }

    @Test("delete removes saved data")
    @MainActor func deleteRemovesSavedData() {
        let data = Data("to-delete".utf8)
        KeychainHelper.save(key: testKey, data: data)

        let deleted = KeychainHelper.delete(key: testKey)
        #expect(deleted == true)

        let result = KeychainHelper.read(key: testKey)
        #expect(result == nil)
    }

    @Test("delete returns false for missing key")
    @MainActor func deleteReturnsFalseForMissingKey() {
        let result = KeychainHelper.delete(key: "nonexistent-key-\(UUID().uuidString)")
        #expect(result == false)
    }

    @Test("save overwrites existing value for same key")
    @MainActor func saveOverwritesExistingValue() {
        let original = Data("original".utf8)
        let updated = Data("updated".utf8)

        KeychainHelper.save(key: testKey, data: original)
        KeychainHelper.save(key: testKey, data: updated)

        let result = KeychainHelper.read(key: testKey)
        #expect(result == updated)

        KeychainHelper.delete(key: testKey)
    }
}
