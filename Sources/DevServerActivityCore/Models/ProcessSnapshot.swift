import Foundation

public struct ProcessSnapshot: Equatable, Hashable, Sendable {
    public let pid: Int
    public let processIdentity: ProcessIdentity?
    public let commandName: String
    public let commandLine: String
    public let workingDirectory: String

    public init(
        pid: Int,
        commandName: String,
        commandLine: String,
        workingDirectory: String
    ) {
        self.init(
            pid: pid,
            processIdentity: nil,
            commandName: commandName,
            commandLine: commandLine,
            workingDirectory: workingDirectory
        )
    }

    public init(
        pid: Int,
        processIdentity: ProcessIdentity?,
        commandName: String,
        commandLine: String,
        workingDirectory: String
    ) {
        self.pid = pid
        self.processIdentity = processIdentity
        self.commandName = commandName
        self.commandLine = commandLine
        self.workingDirectory = workingDirectory
    }
}
