import Foundation

final class AppLogStore {
    static let shared = AppLogStore()

    private let lock = NSLock()
    private let maxEntries: Int
    private var entries: [String] = []

    init(maxEntries: Int = 300) {
        self.maxEntries = maxEntries
    }

    func append(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(message)"

        lock.lock()
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        lock.unlock()
    }

    func recentEntries() -> [String] {
        lock.lock()
        let snapshot = entries
        lock.unlock()
        return snapshot
    }

    func clear() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }
}
