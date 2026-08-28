import Foundation

public struct ListeningPortRecord: Equatable, Hashable, Sendable {
    public let pid: Int
    public let command: String
    public let host: String
    public let port: Int

    public init(pid: Int, command: String, host: String, port: Int) {
        self.pid = pid
        self.command = command
        self.host = host
        self.port = port
    }
}
