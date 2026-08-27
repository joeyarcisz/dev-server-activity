import Darwin
import Foundation
import XCTest
@testable import DevServerActivityCore

final class DevServerTerminatorTests: XCTestCase {
    func testStopsMatchingLiveProcess() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["30"]
        try process.run()
        defer { if process.isRunning { process.terminate() } }

        let pid = Int(process.processIdentifier)
        let server = makeServer(pid: pid, commandLine: "sleep 30", ports: [5173])
        let runner = StubCommandRunner(
            commandLineOutput: "sleep 30\n",
            lsofOutput: lsofLine(pid: pid, port: 5173)
        )

        try DevServerTerminator(runner: runner).stop(server: server, mode: .normal)

        var stopped = false
        for _ in 0..<20 {
            if process.isRunning == false { stopped = true; break }
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTAssertTrue(stopped, "terminator did not stop the validated process")
    }

    func testRejectsInvalidPIDWithoutSignaling() {
        let recorder = SignalRecorder()
        let terminator = makeTerminator(runner: matchingRunner(), recorder: recorder)

        XCTAssertThrowsError(try terminator.stop(server: makeServer(pid: 0), mode: .normal)) { error in
            guard case DevServerTerminatorError.invalidPID(0) = error else {
                return XCTFail("expected invalidPID, got \(error)")
            }
        }
        XCTAssertTrue(recorder.calls.isEmpty)
    }

    func testMatchingTargetUsesSIGTERM() throws {
        let recorder = SignalRecorder()
        let terminator = makeTerminator(runner: matchingRunner(), recorder: recorder)

        try terminator.stop(server: makeServer(), mode: .normal)

        XCTAssertEqual(recorder.calls, [.init(pid: 4242, signal: SIGTERM)])
    }

    func testMatchingTargetUsesSIGKILLForForceStop() throws {
        let recorder = SignalRecorder()
        let terminator = makeTerminator(runner: matchingRunner(), recorder: recorder)

        try terminator.stop(server: makeServer(), mode: .force)

        XCTAssertEqual(recorder.calls, [.init(pid: 4242, signal: SIGKILL)])
    }

    func testRefusesChangedCommandWithoutSignaling() {
        let recorder = SignalRecorder()
        let runner = StubCommandRunner(
            commandLineOutput: "python3 -m http.server 5173\n",
            lsofOutput: lsofLine(pid: 4242, port: 5173)
        )
        let terminator = makeTerminator(runner: runner, recorder: recorder)

        assertTargetChanged(terminator, recorder: recorder)
    }

    func testRefusesMissingExpectedPortWithoutSignaling() {
        let recorder = SignalRecorder()
        let runner = StubCommandRunner(
            commandLineOutput: expectedCommandLine,
            lsofOutput: lsofLine(pid: 4242, port: 3000)
        )
        let terminator = makeTerminator(runner: runner, recorder: recorder)

        assertTargetChanged(terminator, recorder: recorder)
    }

    func testRefusesMissingProcessWithoutSignaling() {
        let recorder = SignalRecorder()
        let runner = StubCommandRunner(
            commandLineOutput: nil,
            lsofOutput: lsofLine(pid: 4242, port: 5173),
            failPS: true
        )
        let terminator = makeTerminator(runner: runner, recorder: recorder)

        assertValidationFailed(terminator, recorder: recorder)
    }

    func testRefusesListeningPortValidationFailureWithoutSignaling() {
        let recorder = SignalRecorder()
        let runner = StubCommandRunner(
            commandLineOutput: expectedCommandLine,
            lsofOutput: nil,
            failLsof: true
        )
        let terminator = makeTerminator(runner: runner, recorder: recorder)

        assertValidationFailed(terminator, recorder: recorder)
    }

    func testReportsSignalFailure() {
        let recorder = SignalRecorder(result: -1, errnoCode: EACCES)
        let terminator = makeTerminator(runner: matchingRunner(), recorder: recorder)

        XCTAssertThrowsError(try terminator.stop(server: makeServer(), mode: .normal)) { error in
            guard case DevServerTerminatorError.killFailed(4242, EACCES) = error else {
                return XCTFail("expected killFailed, got \(error)")
            }
        }
        XCTAssertEqual(recorder.calls, [.init(pid: 4242, signal: SIGTERM)])
    }

    private func assertTargetChanged(
        _ terminator: DevServerTerminator,
        recorder: SignalRecorder,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try terminator.stop(server: makeServer(), mode: .normal),
            file: file,
            line: line
        ) { error in
            guard case DevServerTerminatorError.targetChanged(4242) = error else {
                return XCTFail("expected targetChanged, got \(error)", file: file, line: line)
            }
        }
        XCTAssertTrue(recorder.calls.isEmpty, file: file, line: line)
    }

    private func assertValidationFailed(
        _ terminator: DevServerTerminator,
        recorder: SignalRecorder,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try terminator.stop(server: makeServer(), mode: .normal),
            file: file,
            line: line
        ) { error in
            guard case DevServerTerminatorError.validationFailed(4242) = error else {
                return XCTFail("expected validationFailed, got \(error)", file: file, line: line)
            }
        }
        XCTAssertTrue(recorder.calls.isEmpty, file: file, line: line)
    }
}

private let expectedCommandLine = "node /tmp/example/node_modules/.bin/vite --port 5173"

private func makeServer(
    pid: Int = 4242,
    commandLine: String = expectedCommandLine,
    ports: [Int] = [5173]
) -> DevServer {
    DevServer(
        pid: pid,
        displayName: "example",
        kind: .vite,
        ports: ports,
        hosts: ["*"],
        commandName: "node",
        commandLine: commandLine,
        workingDirectory: "/tmp/example"
    )
}

private func matchingRunner(pid: Int = 4242, port: Int = 5173) -> StubCommandRunner {
    StubCommandRunner(
        commandLineOutput: expectedCommandLine,
        lsofOutput: lsofLine(pid: pid, port: port)
    )
}

private func lsofLine(pid: Int, port: Int) -> String {
    "node \(pid) tester 13u IPv4 0x123 0t0 TCP *:\(port) (LISTEN)"
}

private struct StubCommandRunner: CommandRunning {
    let commandLineOutput: String?
    let lsofOutput: String?
    var failPS = false
    var failLsof = false

    func run(_ executable: String, arguments: [String]) throws -> String {
        switch executable {
        case "/bin/ps":
            if failPS {
                throw CommandRunnerError.failed(executable: executable, status: 1, output: "no such process")
            }
            return commandLineOutput ?? ""
        case "/usr/sbin/lsof":
            if failLsof {
                throw CommandRunnerError.failed(executable: executable, status: 1, output: "validation unavailable")
            }
            return lsofOutput ?? ""
        default:
            throw CommandRunnerError.failed(executable: executable, status: 2, output: "unexpected command")
        }
    }
}

private final class SignalRecorder {
    struct Call: Equatable {
        let pid: Int
        let signal: Int32
    }

    private(set) var calls: [Call] = []
    let result: Int32
    let errnoCode: Int32

    init(result: Int32 = 0, errnoCode: Int32 = 0) {
        self.result = result
        self.errnoCode = errnoCode
    }

    func send(pid: Int, signal: Int32) -> Int32 {
        calls.append(Call(pid: pid, signal: signal))
        return result
    }
}

private func makeTerminator(
    runner: CommandRunning,
    recorder: SignalRecorder
) -> DevServerTerminator {
    DevServerTerminator(
        runner: runner,
        signalProcess: recorder.send,
        errnoProvider: { recorder.errnoCode }
    )
}
