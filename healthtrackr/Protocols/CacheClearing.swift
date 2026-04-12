import Foundation

protocol CacheClearing {
    func clearAllCaches() async
}

extension CacheActor: CacheClearing {}
