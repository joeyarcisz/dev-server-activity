import Foundation

public struct ProcessSnapshot: Equatable, Hashable {
    public let pid: Int
    public let commandName: String
    public let commandLine: String
    public let workingDirectory: String

    public init(pid: Int, commandName: String, commandLine: String, workingDirectory: String) {
        self.pid = pid
        self.commandName = commandName
        self.commandLine = commandLine
        self.workingDirectory = workingDirectory
    }
}
