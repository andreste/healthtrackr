import Foundation

actor CacheActor {
    private let cacheDirectory: URL
    private let defaults = UserDefaults.standard
    private let lastRunKey = "correlationLastRun"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("correlations", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: cacheDirectory.path
        )
    }

    init(directory: URL) {
        cacheDirectory = directory
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: cacheDirectory.path
        )
    }

    // MARK: - Read / Write

    func load(pairId: String) -> CorrelationResult? {
        let url = fileURL(for: pairId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(CorrelationResult.self, from: data)
    }

    func loadAll(pairId: String) -> [CorrelationResult] {
        let url = allResultsURL(for: pairId)
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([CorrelationResult].self, from: data)) ?? []
    }

    func save(results: [CorrelationResult], pairId: String) {
        let url = allResultsURL(for: pairId)
        guard let data = try? encoder.encode(results) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
        defaults.set(Date().timeIntervalSince1970, forKey: "\(lastRunKey)_\(pairId)")
    }

    // MARK: - Staleness

    func isStale(pairId: String, maxAge: TimeInterval = 86400) -> Bool {
        let timestamp = defaults.double(forKey: "\(lastRunKey)_\(pairId)")
        guard timestamp > 0 else { return true }
        return Date().timeIntervalSince1970 - timestamp > maxAge
    }

    // MARK: - Narration Cache

    func loadNarration(pairId: String, lagHours: Int) -> PatternNarration? {
        let url = narrationURL(pairId: pairId, lagHours: lagHours)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(PatternNarration.self, from: data)
    }

    func saveNarration(_ narration: PatternNarration, lagHours: Int) {
        let url = narrationURL(pairId: narration.pairId, lagHours: lagHours)
        guard let data = try? encoder.encode(narration) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    func isNarrationFresh(pairId: String, lagHours: Int, calendar: Calendar = .current) -> Bool {
        guard let narration = loadNarration(pairId: pairId, lagHours: lagHours) else {
            return false
        }
        return calendar.isDateInToday(narration.cachedAt)
    }

    private func narrationURL(pairId: String, lagHours: Int) -> URL {
        cacheDirectory.appendingPathComponent("\(pairId)_narration_\(lagHours).json")
    }

    // MARK: - Clear

    func clearAllCaches() {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in contents where url.pathExtension == "json" {
            try? FileManager.default.removeItem(at: url)
        }
        let prefix = "\(lastRunKey)_"
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Helpers

    private func fileURL(for pairId: String) -> URL {
        cacheDirectory.appendingPathComponent("\(pairId).json")
    }

    private func allResultsURL(for pairId: String) -> URL {
        cacheDirectory.appendingPathComponent("\(pairId)_all.json")
    }
}
