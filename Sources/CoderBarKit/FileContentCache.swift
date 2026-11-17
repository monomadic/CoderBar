import Foundation

/// Caches parsed file content, never time-dependent discovery/filtering decisions.
/// Serialized access also prevents overlapping scans from parsing a file twice.
final class FileContentCache<Value>: @unchecked Sendable {
    private struct Fingerprint: Equatable {
        let size: UInt64
        let modified: Date?
        let created: Date?
        let inode: UInt64

        init(_ url: URL) throws {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
            modified = attributes[.modificationDate] as? Date
            created = attributes[.creationDate] as? Date
            inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
        }
    }

    private struct Entry {
        let fingerprint: Fingerprint
        let value: Value
        var lastAccess: UInt64
    }

    private let capacity: Int
    private let lock = NSLock()
    private var entries: [URL: Entry] = [:]
    private var access: UInt64 = 0

    init(capacity: Int = 256) {
        precondition(capacity > 0)
        self.capacity = capacity
    }

    func value(at url: URL, load: () throws -> Value) throws -> Value {
        lock.lock()
        defer { lock.unlock() }
        let key = url.standardizedFileURL
        let before: Fingerprint
        do {
            before = try Fingerprint(key)
        } catch {
            entries.removeValue(forKey: key)
            throw error
        }
        access &+= 1
        if var entry = entries[key], entry.fingerprint == before {
            entry.lastAccess = access
            entries[key] = entry
            return entry.value
        }
        entries.removeValue(forKey: key)
        let value = try load()
        // A writer may append or replace the file while it is being parsed.
        // Return this scan's result, but force the next scan to reread it.
        guard let after = try? Fingerprint(key), before == after else { return value }
        if entries.count >= capacity,
           let oldest = entries.min(by: { $0.value.lastAccess < $1.value.lastAccess })?.key {
            entries.removeValue(forKey: oldest)
        }
        entries[key] = Entry(fingerprint: after, value: value, lastAccess: access)
        return value
    }
}
