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
        try? data.write(to: url, options: .atomic)
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

    func saveNarration(_ narration: PatternNarration) {
        let url = narrationURL(pairId: narration.pairId, lagHours: 0)
        guard let data = try? encoder.encode(narration) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func narrationURL(pairId: String, lagHours: Int) -> URL {
        cacheDirectory.appendingPathComponent("\(pairId)_narration_\(lagHours).json")
    }

    // MARK: - Helpers

    private func fileURL(for pairId: String) -> URL {
        cacheDirectory.appendingPathComponent("\(pairId).json")
    }

    private func allResultsURL(for pairId: String) -> URL {
        cacheDirectory.appendingPathComponent("\(pairId)_all.json")
    }
}
