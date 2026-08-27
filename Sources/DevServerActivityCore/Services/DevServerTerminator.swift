import Darwin
import Foundation

public enum StopMode: Equatable {
    case normal
    case force

    var signal: Int32 {
        switch self {
        case .normal: SIGTERM
        case .force: SIGKILL
        }
    }
}

public enum DevServerTerminatorError: Error, LocalizedError {
    case invalidPID(Int)
    case validationFailed(Int)
    case targetChanged(Int)
    case killFailed(pid: Int, errnoCode: Int32)

    public var errorDescription: String? {
        switch self {
        case let .invalidPID(pid):
            return "Invalid process id: \(pid)"
        case let .validationFailed(pid):
            return "Could not safely verify process \(pid). The server list was refreshed; select the current server and try again."
        case let .targetChanged(pid):
            return "Process \(pid) changed since the last scan, so it was not stopped. The server list was refreshed."
        case let .killFailed(pid, errnoCode):
            return "Could not stop process \(pid). errno=\(errnoCode)"
        }
    }
}

public struct DevServerTerminator {
    private let runner: CommandRunning
    private let parser: LsofParser
    private let signalProcess: (Int, Int32) -> Int32
    private let errnoProvider: () -> Int32

    public init() {
        self.init(runner: ShellCommandRunner())
    }

    init(
        runner: CommandRunning,
        parser: LsofParser = LsofParser(),
        signalProcess: @escaping (Int, Int32) -> Int32 = { pid, signal in
            Darwin.kill(pid_t(pid), signal)
        },
        errnoProvider: @escaping () -> Int32 = { errno }
    ) {
        self.runner = runner
        self.parser = parser
        self.signalProcess = signalProcess
        self.errnoProvider = errnoProvider
    }

    public func stop(server: DevServer, mode: StopMode) throws {
        let pid = server.pid ?? 0
        guard pid > 0 else {
            throw DevServerTerminatorError.invalidPID(pid)
        }

        guard
            let expectedCommandLine = server.commandLine.trimmedNonEmpty,
            server.ports.isEmpty == false
        else {
            throw DevServerTerminatorError.targetChanged(pid)
        }

        let currentCommandLine: String
        do {
            guard let value = try runner.run(
                "/bin/ps",
                arguments: ["-p", "\(pid)", "-o", "args="]
            ).trimmedNonEmpty else {
                throw DevServerTerminatorError.targetChanged(pid)
            }
            currentCommandLine = value
        } catch let error as DevServerTerminatorError {
            throw error
        } catch {
            throw DevServerTerminatorError.validationFailed(pid)
        }

        guard currentCommandLine == expectedCommandLine else {
            throw DevServerTerminatorError.targetChanged(pid)
        }

        let listeningOutput: String
        do {
            listeningOutput = try runner.run(
                "/usr/sbin/lsof",
                arguments: ["-nP", "-a", "-p", "\(pid)", "-iTCP", "-sTCP:LISTEN"]
            )
        } catch {
            throw DevServerTerminatorError.validationFailed(pid)
        }

        let expectedPorts = Set(server.ports)
        let currentPorts = Set(
            parser.parseListeningRecords(listeningOutput)
                .filter { $0.pid == pid }
                .map(\.port)
        )
        guard expectedPorts.isDisjoint(with: currentPorts) == false else {
            throw DevServerTerminatorError.targetChanged(pid)
        }

        let result = signalProcess(pid, mode.signal)
        if result != 0 {
            throw DevServerTerminatorError.killFailed(pid: pid, errnoCode: errnoProvider())
        }
    }
}
