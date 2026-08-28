import Darwin
import Foundation

public struct ProcessIdentity: Equatable, Hashable, Sendable {
    public let startTimeSeconds: UInt64
    public let startTimeMicroseconds: UInt64

    public init(startTimeSeconds: UInt64, startTimeMicroseconds: UInt64) {
        self.startTimeSeconds = startTimeSeconds
        self.startTimeMicroseconds = startTimeMicroseconds
    }
}

public protocol ProcessIdentityProviding: Sendable {
    func identity(for pid: Int) -> ProcessIdentity?
}

public struct DarwinProcessIdentityProvider: ProcessIdentityProviding {
    public init() {}

    public func identity(for pid: Int) -> ProcessIdentity? {
        guard pid > 0, pid <= Int(Int32.max) else { return nil }

        var info = proc_bsdinfo()
        let expectedSize = Int32(MemoryLayout<proc_bsdinfo>.size)
        let result = proc_pidinfo(Int32(pid), PROC_PIDTBSDINFO, 0, &info, expectedSize)
        guard result == expectedSize else { return nil }

        return ProcessIdentity(
            startTimeSeconds: UInt64(info.pbi_start_tvsec),
            startTimeMicroseconds: UInt64(info.pbi_start_tvusec)
        )
    }
}
