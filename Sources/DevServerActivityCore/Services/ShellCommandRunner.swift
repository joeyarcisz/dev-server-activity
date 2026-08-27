import Foundation

public protocol CommandRunning {
    func run(_ executable: String, arguments: [String]) throws -> String
}

public enum CommandRunnerError: Error, LocalizedError {
    case failed(executable: String, status: Int32, output: String)

    public var errorDescription: String? {
        switch self {
        case let .failed(executable, status, output):
            return "\(executable) exited with status \(status): \(output)"
        }
    }
}

public struct ShellCommandRunner: CommandRunning {
    public init() {}

    public func run(_ executable: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw CommandRunnerError.failed(
                executable: executable,
                status: process.terminationStatus,
                output: output
            )
        }

        return output
    }
}
