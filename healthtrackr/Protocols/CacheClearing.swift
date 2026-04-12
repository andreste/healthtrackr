import Foundation

protocol CacheInvalidating {
    func clearAllCaches() async
}

extension CacheActor: CacheInvalidating {}
