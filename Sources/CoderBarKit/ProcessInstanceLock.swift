import Foundation
import Darwin

/// A process-lifetime advisory lock, released by the kernel even after a crash.
/// Never unlink the lock file: doing so allows two processes to lock different inodes.
public final class ProcessInstanceLock {
    private let descriptor: Int32

    public init?(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let fd = open(url.path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            let code = errno
            close(fd)
            if code == EWOULDBLOCK { return nil }
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
        descriptor = fd
    }

    deinit { close(descriptor) }
}
