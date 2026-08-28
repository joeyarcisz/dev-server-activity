import Darwin
import Foundation

public protocol CommandRunning {
    func run(_ executable: String, arguments: [String]) throws -> String
}

public enum CommandRunnerError: Error, LocalizedError, Sendable {
    case failed(executable: String, status: Int32, output: String)

    public var errorDescription: String? {
        switch self {
        case let .failed(executable, status, output):
            return "\(executable) exited with status \(status): \(output)"
        }
    }
}

public enum CommandExecutionError: Error, LocalizedError, Sendable {
    case launchFailed(executable: String, description: String)
    case timedOut(executable: String, timeout: TimeInterval)
    case outputLimitExceeded(executable: String, limit: Int)
    case readFailed(executable: String, description: String)
    case invalidUTF8(executable: String)
    case processLifecycleFailed(executable: String, description: String)

    public var errorDescription: String? {
        switch self {
        case let .launchFailed(executable, description):
            return "Could not launch \(executable): \(description)"
        case let .timedOut(executable, timeout):
            return "\(executable) exceeded its \(timeout)-second timeout"
        case let .outputLimitExceeded(executable, limit):
            return "\(executable) produced more than \(limit) bytes of output"
        case let .readFailed(executable, description):
            return "Could not read output from \(executable): \(description)"
        case let .invalidUTF8(executable):
            return "\(executable) returned output that was not valid UTF-8"
        case let .processLifecycleFailed(executable, description):
            return "Could not safely finish \(executable): \(description)"
        }
    }
}

public struct ShellCommandRunner: CommandRunning, Sendable {
    private let timeout: TimeInterval
    private let maximumOutputBytes: Int

    public init() {
        self.init(timeout: 5)
    }

    public init(timeout: TimeInterval, maximumOutputBytes: Int = 4 * 1_024 * 1_024) {
        precondition(timeout > 0, "timeout must be positive")
        precondition(maximumOutputBytes > 0, "maximumOutputBytes must be positive")
        self.timeout = timeout
        self.maximumOutputBytes = maximumOutputBytes
    }

    public func run(_ executable: String, arguments: [String]) throws -> String {
        let launchedCommand = try CommandProcessController.launch(
            executable: executable,
            arguments: arguments
        )
        let processController = launchedCommand.controller
        let readHandle = launchedCommand.readHandle
        let state = CommandExecutionState(maximumOutputBytes: maximumOutputBytes)
        let readerGroup = DispatchGroup()

        readerGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                state.recordReaderCompletion()
                readerGroup.leave()
            }

            do {
                while let chunk = try readHandle.read(upToCount: 16_384), chunk.isEmpty == false {
                    if state.append(chunk) {
                        processController.terminate()
                        break
                    }
                }
            } catch {
                if state.recordReadFailure(error.localizedDescription) {
                    processController.terminate()
                }
            }
        }

        let timeoutWorkItem = DispatchWorkItem {
            processController.terminate {
                state.recordTimeout()
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + timeout,
            execute: timeoutWorkItem
        )

        let exitObservationError = processController.waitUntilExitWithoutReaping()
        state.recordProcessCompletion()
        readerGroup.wait()
        processController.beginReapingAfterTerminationRequestCompletes()
        let reapError = processController.reap()
        timeoutWorkItem.cancel()

        if let lifecycleFailure = processController.terminationFailureAfterReaping() {
            throw CommandExecutionError.processLifecycleFailed(
                executable: executable,
                description: lifecycleFailure
            )
        }
        if let exitObservationError {
            throw CommandExecutionError.processLifecycleFailed(
                executable: executable,
                description: "waitid failed with errno \(exitObservationError)"
            )
        }
        if let reapError {
            throw CommandExecutionError.processLifecycleFailed(
                executable: executable,
                description: "waitpid failed with errno \(reapError)"
            )
        }

        switch state.abortReason {
        case .timedOut:
            throw CommandExecutionError.timedOut(executable: executable, timeout: timeout)
        case .outputLimitExceeded:
            throw CommandExecutionError.outputLimitExceeded(
                executable: executable,
                limit: maximumOutputBytes
            )
        case let .readFailed(description):
            throw CommandExecutionError.readFailed(executable: executable, description: description)
        case nil:
            break
        }

        guard let output = String(data: state.output, encoding: .utf8) else {
            throw CommandExecutionError.invalidUTF8(executable: executable)
        }

        guard processController.terminationStatus == 0 else {
            throw CommandRunnerError.failed(
                executable: executable,
                status: processController.terminationStatus,
                output: output
            )
        }

        return output
    }
}

private final class CommandProcessController: @unchecked Sendable {
    private let lock = NSLock()
    private let processIdentifier: pid_t
    private let lifecycle = ProcessGroupLifecycleGate()
    private var rawWaitStatus: Int32?
    private var terminationSignalError: Int32?

    private init(processIdentifier: pid_t) {
        self.processIdentifier = processIdentifier
    }

    struct LaunchResult {
        let controller: CommandProcessController
        let readHandle: FileHandle
    }

    var terminationStatus: Int32 {
        lock.withLock {
            guard let rawWaitStatus else { return -1 }
            let terminatingSignal = rawWaitStatus & 0x7F
            if terminatingSignal == 0 {
                return (rawWaitStatus >> 8) & 0xFF
            }
            return terminatingSignal
        }
    }

    func waitUntilExitWithoutReaping() -> Int32? {
        var info = siginfo_t()
        var result: Int32
        repeat {
            result = Darwin.waitid(
                P_PID,
                UInt32(processIdentifier),
                &info,
                WEXITED | WNOWAIT
            )
        } while result == -1 && errno == EINTR

        return result == 0 ? nil : errno
    }

    func reap() -> Int32? {
        var status: Int32 = 0
        var result: pid_t
        repeat {
            result = Darwin.waitpid(processIdentifier, &status, 0)
        } while result == -1 && errno == EINTR
        let waitError = errno

        lock.withLock {
            rawWaitStatus = result == processIdentifier ? status : -1
        }

        return result == processIdentifier ? nil : waitError
    }

    func terminate(if shouldTerminate: () -> Bool = { true }) {
        guard lifecycle.beginTermination(if: shouldTerminate) else { return }
        defer { lifecycle.finishTermination() }

        errno = 0
        let signalResult = Darwin.kill(-processIdentifier, SIGKILL)
        let signalError = errno
        if signalResult == -1, signalError != ESRCH {
            lock.withLock {
                terminationSignalError = signalError
            }
        }
    }

    func beginReapingAfterTerminationRequestCompletes() {
        lifecycle.beginReapingAndWait()
    }

    func terminationFailureAfterReaping() -> String? {
        let state = lock.withLock {
            (requested: lifecycle.didRequestTermination, signalError: terminationSignalError)
        }
        guard state.requested else { return nil }
        return processGroupCleanupFailure(
            processIdentifier: processIdentifier,
            signalError: state.signalError,
            maximumAttempts: 100,
            probe: {
                errno = 0
                let result = Darwin.kill(-processIdentifier, 0)
                return (result, errno)
            },
            pause: {
                Thread.sleep(forTimeInterval: 0.01)
            }
        )
    }

    static func launch(executable: String, arguments: [String]) throws -> LaunchResult {
        guard ([executable] + arguments).allSatisfy({ $0.contains("\0") == false }) else {
            throw CommandExecutionError.launchFailed(
                executable: executable,
                description: "executable and arguments must not contain NUL bytes"
            )
        }

        var descriptors: [Int32] = [0, 0]
        guard Darwin.pipe(&descriptors) == 0 else {
            throw launchError(executable: executable, code: errno)
        }

        let readDescriptor = descriptors[0]
        let writeDescriptor = descriptors[1]
        var readDescriptorIsOpen = true
        var writeDescriptorIsOpen = true
        defer {
            if readDescriptorIsOpen {
                Darwin.close(readDescriptor)
            }
            if writeDescriptorIsOpen {
                Darwin.close(writeDescriptor)
            }
        }

        guard
            Darwin.fcntl(readDescriptor, F_SETFD, FD_CLOEXEC) != -1,
            Darwin.fcntl(writeDescriptor, F_SETFD, FD_CLOEXEC) != -1
        else {
            throw launchError(executable: executable, code: errno)
        }

        var fileActions: posix_spawn_file_actions_t?
        var result = posix_spawn_file_actions_init(&fileActions)
        guard result == 0 else {
            throw launchError(executable: executable, code: result)
        }
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        for action in [
            posix_spawn_file_actions_adddup2(&fileActions, writeDescriptor, STDOUT_FILENO),
            posix_spawn_file_actions_adddup2(&fileActions, writeDescriptor, STDERR_FILENO),
            posix_spawn_file_actions_addclose(&fileActions, readDescriptor),
            posix_spawn_file_actions_addclose(&fileActions, writeDescriptor)
        ] {
            guard action == 0 else {
                throw launchError(executable: executable, code: action)
            }
        }

        var attributes: posix_spawnattr_t?
        result = posix_spawnattr_init(&attributes)
        guard result == 0 else {
            throw launchError(executable: executable, code: result)
        }
        defer { posix_spawnattr_destroy(&attributes) }

        result = posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP))
        guard result == 0 else {
            throw launchError(executable: executable, code: result)
        }
        result = posix_spawnattr_setpgroup(&attributes, 0)
        guard result == 0 else {
            throw launchError(executable: executable, code: result)
        }

        let argumentStrings = [executable] + arguments
        var duplicatedArguments = argumentStrings.map { strdup($0) }
        guard duplicatedArguments.allSatisfy({ $0 != nil }) else {
            duplicatedArguments.forEach { free($0) }
            throw CommandExecutionError.launchFailed(
                executable: executable,
                description: "could not allocate process arguments"
            )
        }
        defer { duplicatedArguments.forEach { free($0) } }
        duplicatedArguments.append(nil)

        var spawnedPID: pid_t = 0
        result = executable.withCString { executablePath in
            duplicatedArguments.withUnsafeBufferPointer { argumentBuffer in
                posix_spawn(
                    &spawnedPID,
                    executablePath,
                    &fileActions,
                    &attributes,
                    argumentBuffer.baseAddress,
                    environ
                )
            }
        }
        guard result == 0 else {
            throw launchError(executable: executable, code: result)
        }

        Darwin.close(writeDescriptor)
        writeDescriptorIsOpen = false
        let readHandle = FileHandle(fileDescriptor: readDescriptor, closeOnDealloc: true)
        readDescriptorIsOpen = false

        return LaunchResult(
            controller: CommandProcessController(processIdentifier: spawnedPID),
            readHandle: readHandle
        )
    }

    private static func launchError(executable: String, code: Int32) -> CommandExecutionError {
        CommandExecutionError.launchFailed(
            executable: executable,
            description: String(cString: strerror(code))
        )
    }
}

final class ProcessGroupLifecycleGate: @unchecked Sendable {
    private let lock = NSLock()
    private let terminationGroup = DispatchGroup()
    private var terminationRequested = false
    private var reapingStarted = false

    var didRequestTermination: Bool {
        lock.withLock { terminationRequested }
    }

    func beginTermination(if shouldTerminate: () -> Bool) -> Bool {
        lock.withLock {
            guard terminationRequested == false, reapingStarted == false else { return false }
            guard shouldTerminate() else { return false }
            terminationRequested = true
            terminationGroup.enter()
            return true
        }
    }

    func finishTermination() {
        terminationGroup.leave()
    }

    func beginReapingAndWait() {
        let mustWait = lock.withLock {
            reapingStarted = true
            return terminationRequested
        }
        if mustWait {
            terminationGroup.wait()
        }
    }
}

func processGroupCleanupFailure(
    processIdentifier: pid_t,
    signalError: Int32?,
    maximumAttempts: Int,
    probe: () -> (result: Int32, error: Int32),
    pause: () -> Void
) -> String? {
    precondition(maximumAttempts > 0, "maximumAttempts must be positive")

    if let signalError, signalError != EPERM {
        return "SIGKILL for process group \(processIdentifier) failed with errno \(signalError)"
    }

    for _ in 0..<maximumAttempts {
        let result = probe()
        if result.result == -1 {
            if result.error == ESRCH {
                return nil
            }
            if result.error != EPERM {
                return "process-group cleanup check failed with errno \(result.error)"
            }
        }
        pause()
    }

    if signalError == EPERM {
        return "SIGKILL for process group \(processIdentifier) returned EPERM and the group remained present"
    }
    return "process group \(processIdentifier) still existed one second after SIGKILL"
}

private enum CommandAbortReason {
    case timedOut
    case outputLimitExceeded
    case readFailed(String)
}

private final class CommandExecutionState: @unchecked Sendable {
    private let lock = NSLock()
    private let maximumOutputBytes: Int
    private var data = Data()
    private var reason: CommandAbortReason?
    private var processCompleted = false
    private var readerCompleted = false

    init(maximumOutputBytes: Int) {
        self.maximumOutputBytes = maximumOutputBytes
    }

    var output: Data {
        lock.withLock { data }
    }

    var abortReason: CommandAbortReason? {
        lock.withLock { reason }
    }

    func append(_ chunk: Data) -> Bool {
        lock.withLock {
            guard reason == nil else { return false }
            guard chunk.count <= maximumOutputBytes - data.count else {
                reason = .outputLimitExceeded
                return true
            }
            data.append(chunk)
            return false
        }
    }

    func recordTimeout() -> Bool {
        record(.timedOut)
    }

    func recordReadFailure(_ description: String) -> Bool {
        record(.readFailed(description))
    }

    func recordProcessCompletion() {
        lock.withLock {
            processCompleted = true
        }
    }

    func recordReaderCompletion() {
        lock.withLock {
            readerCompleted = true
        }
    }

    private func record(_ newReason: CommandAbortReason) -> Bool {
        lock.withLock {
            guard processCompleted == false || readerCompleted == false, reason == nil else { return false }
            reason = newReason
            return true
        }
    }
}
