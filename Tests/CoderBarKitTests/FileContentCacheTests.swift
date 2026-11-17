import Foundation

private func expectEqual<T: Equatable>(_ actual: @autoclosure () throws -> T, _ expected: T) throws {
    let value = try actual()
    precondition(value == expected, "Expected \(expected), got \(value)")
}

private func expectError<T>(_ operation: @autoclosure () throws -> T) {
    do { _ = try operation() } catch { return }
    preconditionFailure("Expected an error")
}

final class FileContentCacheTests {
    private var directory: URL!

    func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testUnchangedFilesParseOnlyOnce() throws {
        let file = directory.appendingPathComponent("session")
        try Data("first".utf8).write(to: file)
        let cache = FileContentCache<String>()
        var reads = 0
        for _ in 0..<100 {
            let value = try cache.value(at: file) { reads += 1; return try String(contentsOf: file, encoding: .utf8) }
            try expectEqual(value, "first")
        }
        try expectEqual(reads, 1)
    }

    func testAppendTruncationAndSameSizeReplacementInvalidate() throws {
        let file = directory.appendingPathComponent("session")
        let cache = FileContentCache<String>()
        for text in ["a", "appended", "b", "c"] {
            try Data(text.utf8).write(to: file, options: .atomic)
            try expectEqual(try cache.value(at: file) { try String(contentsOf: file, encoding: .utf8) }, text)
        }
    }

    func testDeletionDoesNotReturnStaleContent() throws {
        let file = directory.appendingPathComponent("session")
        try Data().write(to: file)
        let cache = FileContentCache<Int>()
        _ = try cache.value(at: file) { 1 }
        try FileManager.default.removeItem(at: file)
        expectError(try cache.value(at: file) { 2 })
    }

    func testFailuresAndConcurrentWritesAreNotCached() throws {
        let file = directory.appendingPathComponent("session")
        try Data().write(to: file)
        let cache = FileContentCache<Int>()
        expectError(try cache.value(at: file) { throw NSError(domain: "parse", code: 1) })
        _ = try cache.value(at: file) { try Data("changed".utf8).write(to: file); return 1 }
        try expectEqual(try cache.value(at: file) { 2 }, 2)
    }

    func testLeastRecentlyUsedEntriesAreEvicted() throws {
        let files = (0..<3).map { directory.appendingPathComponent("\($0)") }
        for file in files { try Data().write(to: file) }
        let cache = FileContentCache<Int>(capacity: 2)
        _ = try cache.value(at: files[0]) { 0 }
        _ = try cache.value(at: files[1]) { 1 }
        try expectEqual(try cache.value(at: files[0]) { -1 }, 0)
        _ = try cache.value(at: files[2]) { 2 }
        try expectEqual(try cache.value(at: files[1]) { 10 }, 10)
    }
}

@main
struct CacheTestRunner {
    static func main() throws {
        let tests = FileContentCacheTests()
        let checks = [tests.testUnchangedFilesParseOnlyOnce,
                      tests.testAppendTruncationAndSameSizeReplacementInvalidate,
                      tests.testDeletionDoesNotReturnStaleContent,
                      tests.testFailuresAndConcurrentWritesAreNotCached,
                      tests.testLeastRecentlyUsedEntriesAreEvicted]
        for check in checks {
            try tests.setUpWithError()
            defer { try? tests.tearDownWithError() }
            try check()
        }
        print("Passed \(checks.count) file-cache regression checks")
        try benchmark()
    }

    static func benchmark() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let rows = (0..<4000).map { ["type": "assistant", "message": "Synthetic transcript event \($0)"] }
        try JSONSerialization.data(withJSONObject: rows).write(to: file)
        func parse() throws -> Int {
            (try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [[String: String]]).count
        }
        let start = ProcessInfo.processInfo.systemUptime
        for _ in 0..<100 { _ = try parse() }
        let uncached = ProcessInfo.processInfo.systemUptime - start
        let cache = FileContentCache<Int>()
        var parses = 0
        let cachedStart = ProcessInfo.processInfo.systemUptime
        for _ in 0..<100 { _ = try cache.value(at: file) { parses += 1; return try parse() } }
        let cached = ProcessInfo.processInfo.systemUptime - cachedStart
        precondition(parses == 1)
        print(String(format: "Synthetic 100-poll benchmark: uncached %.3fs, cached %.3fs; parses 100 -> %d", uncached, cached, parses))
    }
}
