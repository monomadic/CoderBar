import Foundation

@main
struct ProcessInstanceLockTests {
    static func main() throws {
        if CommandLine.arguments.count == 3 {
            let lock = try ProcessInstanceLock(url: URL(fileURLWithPath: CommandLine.arguments[1]))
            let expected = CommandLine.arguments[2] == "available"
            guard (lock != nil) == expected else { fatalError("Unexpected child lock result") }
            return
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("instance.lock")
        var first = try ProcessInstanceLock(url: url)
        precondition(first != nil)
        let second = try ProcessInstanceLock(url: url)
        precondition(second == nil)
        func child(_ expected: String) throws {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
            process.arguments = [url.path, expected]
            try process.run()
            process.waitUntilExit()
            precondition(process.terminationStatus == 0)
        }
        try child("blocked")
        first = nil
        try child("available")
        precondition(FileManager.default.fileExists(atPath: url.path))
        print("PASS: same-process and cross-process exclusion; release and reacquisition")
    }
}
