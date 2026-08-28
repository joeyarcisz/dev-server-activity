import Darwin
import Foundation
import XCTest
@testable import DevServerActivityCore

final class ShellCommandRunnerTests: XCTestCase {
    func testDrainsOutputLargerThanPipeCapacity() throws {
        let runner = ShellCommandRunner(timeout: 2, maximumOutputBytes: 1_000_000)

        let output = try runner.run("/usr/bin/jot", arguments: ["-b", "x", "100000"])

        XCTAssertGreaterThan(output.utf8.count, 65_536)
        XCTAssertEqual(output.split(whereSeparator: \.isNewline).count, 100_000)
    }

    func testTimesOutStalledProcess() {
        let runner = ShellCommandRunner(timeout: 0.05, maximumOutputBytes: 1_000_000)
        let startedAt = Date()

        XCTAssertThrowsError(try runner.run("/bin/sleep", arguments: ["5"])) { error in
            guard case CommandExecutionError.timedOut("/bin/sleep", 0.05) = error else {
                return XCTFail("expected timedOut, got \(error)")
            }
        }

        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 1)
    }

    func testTimesOutWhenDescendantKeepsOutputPipeOpen() {
        let runner = ShellCommandRunner(timeout: 0.05, maximumOutputBytes: 1_000_000)
        let startedAt = Date()

        XCTAssertThrowsError(
            try runner.run(
                "/bin/sh",
                arguments: ["-c", "(set -e; while :; do printf x; /bin/sleep 0.1; done) &"]
            )
        ) { error in
            guard case CommandExecutionError.timedOut("/bin/sh", 0.05) = error else {
                return XCTFail("expected timedOut, got \(error)")
            }
        }

        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 1)
    }

    func testTimeoutTerminatesDescendantProcess() throws {
        let pidFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("dev-server-activity-child-\(UUID().uuidString).pid")
        defer { try? FileManager.default.removeItem(at: pidFile) }

        let runner = ShellCommandRunner(timeout: 0.2, maximumOutputBytes: 1_000_000)
        XCTAssertThrowsError(
            try runner.run(
                "/usr/bin/python3",
                arguments: [
                    "-c",
                    "import subprocess, sys, time; child = subprocess.Popen(['/bin/sh', '-c', \"trap '' TERM HUP; exec /bin/sleep 30\"]); handle = open(sys.argv[1], 'w'); handle.write(str(child.pid)); handle.close(); time.sleep(30)",
                    pidFile.path
                ]
            )
        ) { error in
            guard case CommandExecutionError.timedOut("/usr/bin/python3", 0.2) = error else {
                return XCTFail("expected timedOut, got \(error)")
            }
        }

        let childPID = try XCTUnwrap(
            Int(String(contentsOf: pidFile, encoding: .utf8))
        )
        defer {
            if Darwin.kill(pid_t(childPID), 0) == 0 {
                Darwin.kill(pid_t(childPID), SIGKILL)
            }
        }

        XCTAssertTrue(
            waitUntilProcessExits(pid: childPID, timeout: 2),
            "timed-out descendant \(childPID) remained alive"
        )
    }

    func testTimeoutTerminatesDescendantAfterParentExits() throws {
        let pidFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("dev-server-activity-orphan-\(UUID().uuidString).pid")
        defer { try? FileManager.default.removeItem(at: pidFile) }

        let runner = ShellCommandRunner(timeout: 0.2, maximumOutputBytes: 1_000_000)
        XCTAssertThrowsError(
            try runner.run(
                "/usr/bin/python3",
                arguments: [
                    "-c",
                    "import subprocess, sys; child = subprocess.Popen(['/bin/sh', '-c', \"trap '' TERM HUP; exec /bin/sleep 30\"]); handle = open(sys.argv[1], 'w'); handle.write(str(child.pid)); handle.close()",
                    pidFile.path
                ]
            )
        ) { error in
            guard case CommandExecutionError.timedOut("/usr/bin/python3", 0.2) = error else {
                return XCTFail("expected timedOut, got \(error)")
            }
        }

        let childPID = try XCTUnwrap(
            Int(String(contentsOf: pidFile, encoding: .utf8))
        )
        defer {
            if Darwin.kill(pid_t(childPID), 0) == 0 {
                Darwin.kill(pid_t(childPID), SIGKILL)
            }
        }

        XCTAssertTrue(
            waitUntilProcessExits(pid: childPID, timeout: 2),
            "orphaned descendant \(childPID) remained alive"
        )
    }

    func testReportsTypedLaunchFailure() {
        let runner = ShellCommandRunner(timeout: 1, maximumOutputBytes: 1_000_000)

        XCTAssertThrowsError(
            try runner.run("/path/that/does/not/exist", arguments: [])
        ) { error in
            guard case CommandExecutionError.launchFailed("/path/that/does/not/exist", _) = error else {
                return XCTFail("expected launchFailed, got \(error)")
            }
        }
    }

    func testRejectsOutputAboveLimit() {
        let runner = ShellCommandRunner(timeout: 2, maximumOutputBytes: 1_024)

        XCTAssertThrowsError(try runner.run("/usr/bin/jot", arguments: ["-b", "x", "10000"])) { error in
            guard case CommandExecutionError.outputLimitExceeded("/usr/bin/jot", 1_024) = error else {
                return XCTFail("expected outputLimitExceeded, got \(error)")
            }
        }
    }

    func testOutputLimitTerminatesDescendantProcess() throws {
        let pidFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("dev-server-activity-output-child-\(UUID().uuidString).pid")
        defer { try? FileManager.default.removeItem(at: pidFile) }

        let runner = ShellCommandRunner(timeout: 2, maximumOutputBytes: 1_024)
        XCTAssertThrowsError(
            try runner.run(
                "/usr/bin/python3",
                arguments: [
                    "-c",
                    "import os, subprocess, sys, time; child = subprocess.Popen(['/bin/sh', '-c', \"trap '' TERM HUP; exec /bin/sleep 30\"]); handle = open(sys.argv[1], 'w'); handle.write(str(child.pid)); handle.close(); os.write(1, b'x' * 100000); time.sleep(30)",
                    pidFile.path
                ]
            )
        ) { error in
            guard case CommandExecutionError.outputLimitExceeded("/usr/bin/python3", 1_024) = error else {
                return XCTFail("expected outputLimitExceeded, got \(error)")
            }
        }

        let childPID = try XCTUnwrap(
            Int(String(contentsOf: pidFile, encoding: .utf8))
        )
        defer {
            if Darwin.kill(pid_t(childPID), 0) == 0 {
                Darwin.kill(pid_t(childPID), SIGKILL)
            }
        }

        XCTAssertTrue(
            waitUntilProcessExits(pid: childPID, timeout: 2),
            "output-limited descendant \(childPID) remained alive"
        )
    }

    func testDefersEPERMSignalFailureUntilTheGroupDisappears() {
        var probes: [(result: Int32, error: Int32)] = [
            (-1, EPERM),
            (-1, ESRCH)
        ]

        let failure = processGroupCleanupFailure(
            processIdentifier: 123,
            signalError: EPERM,
            maximumAttempts: probes.count,
            probe: { probes.removeFirst() },
            pause: {}
        )

        XCTAssertNil(failure)
    }

    func testReportsEPERMSignalFailureWhenTheGroupRemainsPresent() {
        let failure = processGroupCleanupFailure(
            processIdentifier: 123,
            signalError: EPERM,
            maximumAttempts: 2,
            probe: { (-1, EPERM) },
            pause: {}
        )

        XCTAssertEqual(
            failure,
            "SIGKILL for process group 123 returned EPERM and the group remained present"
        )
    }

    func testReapingWaitsForAnInFlightTermination() {
        let gate = ProcessGroupLifecycleGate()
        XCTAssertTrue(gate.beginTermination(if: { true }))

        let reapingFinished = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            gate.beginReapingAndWait()
            reapingFinished.signal()
        }

        XCTAssertEqual(reapingFinished.wait(timeout: .now() + 0.05), .timedOut)
        gate.finishTermination()
        XCTAssertEqual(reapingFinished.wait(timeout: .now() + 1), .success)
    }

    func testTerminationCannotStartAfterReapingBegins() {
        let gate = ProcessGroupLifecycleGate()
        gate.beginReapingAndWait()
        var predicateWasEvaluated = false

        let started = gate.beginTermination {
            predicateWasEvaluated = true
            return true
        }

        XCTAssertFalse(started)
        XCTAssertFalse(predicateWasEvaluated)
    }

    private func waitUntilProcessExits(pid: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            errno = 0
            if Darwin.kill(pid_t(pid), 0) == -1, errno == ESRCH {
                return true
            }
            Thread.sleep(forTimeInterval: 0.02)
        } while Date() < deadline

        return false
    }
}
