import Foundation
import XCTest
@testable import DevServerActivityCore

final class DevServerDetectorTests: XCTestCase {
    func testBuildsDevServersFromListeningPortsAndProcessDetails() {
        let records = [
            ListeningPortRecord(pid: 1905, command: "ControlCe", host: "*", port: 5000),
            ListeningPortRecord(pid: 47874, command: "node", host: "*", port: 5177),
            ListeningPortRecord(pid: 76870, command: "node", host: "*", port: 3000),
            ListeningPortRecord(pid: 76870, command: "node", host: "*", port: 3000),
            ListeningPortRecord(pid: 94899, command: "node", host: "*", port: 3001),
            ListeningPortRecord(pid: 62357, command: "IPNExtens", host: "*", port: 36186)
        ]
        let processes = [
            1905: ProcessSnapshot(
                pid: 1905,
                processIdentity: identity(for: 1905),
                commandName: "ControlCenter",
                commandLine: "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter",
                workingDirectory: "/"
            ),
            47874: ProcessSnapshot(
                pid: 47874,
                processIdentity: identity(for: 47874),
                commandName: "node",
                commandLine: "node /Users/tester/Projects/production-hq/node_modules/.bin/vite --host 0.0.0.0 --port 5177",
                workingDirectory: "/Users/tester/Projects/production-hq"
            ),
            76870: ProcessSnapshot(
                pid: 76870,
                processIdentity: identity(for: 76870),
                commandName: "next-server (v16.1.6)",
                commandLine: "next-server (v16.1.6)",
                workingDirectory: "/Users/tester/.Trash/GitHub/example-app"
            ),
            94899: ProcessSnapshot(
                pid: 94899,
                processIdentity: identity(for: 94899),
                commandName: "next-server (v16.2.6)",
                commandLine: "next-server (v16.2.6)",
                workingDirectory: "/Users/tester/Projects/example-site/.worktrees/feature-branch"
            ),
            62357: ProcessSnapshot(
                pid: 62357,
                processIdentity: identity(for: 62357),
                commandName: "IPNExtension",
                commandLine: "/Applications/Tailscale.app/Contents/PlugIns/IPNExtension.appex/Contents/MacOS/IPNExtension",
                workingDirectory: "/"
            )
        ]

        let servers = DevServerDetector().detect(records: records, processes: processes)

        XCTAssertEqual(servers.map(\.pid), [76870, 94899, 47874])
        XCTAssertEqual(servers.first?.displayName, "example-app")
        XCTAssertEqual(servers.first?.kind, .next)
        XCTAssertEqual(servers.first?.ports, [3000])
        XCTAssertEqual(servers.first?.processIdentity, identity(for: 76870))
        XCTAssertTrue(servers.first?.canStop == true)
        XCTAssertEqual(servers.last?.displayName, "production-hq")
        XCTAssertEqual(servers.last?.kind, .vite)
    }

    func testParsesLsofOutputIntoListeningRecords() throws {
        let output = """
        COMMAND     PID       USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        node      47874 tester   13u  IPv4 0xb9c7348169ef7b1a      0t0  TCP *:5177 (LISTEN)
        node      76870 tester   17u  IPv6 0xd54b2d9e5429ee52      0t0  TCP *:3000 (LISTEN)
        python3.1  4565 tester   10u  IPv4 0x90a6e4198029f2b1      0t0  TCP 127.0.0.1:9119 (LISTEN)
        """

        let records = LsofParser().parseListeningRecords(output)

        XCTAssertEqual(records, [
            ListeningPortRecord(pid: 47874, command: "node", host: "*", port: 5177),
            ListeningPortRecord(pid: 76870, command: "node", host: "*", port: 3000),
            ListeningPortRecord(pid: 4565, command: "python3.1", host: "127.0.0.1", port: 9119)
        ])
    }

    func testRejectsInvalidPIDsAndPortsInLsofOutput() {
        let output = """
        node -1 tester 13u IPv4 0x1 0t0 TCP *:5173 (LISTEN)
        node 0 tester 13u IPv4 0x2 0t0 TCP *:5173 (LISTEN)
        node 42 tester 13u IPv4 0x3 0t0 TCP *:-1 (LISTEN)
        node 42 tester 13u IPv4 0x4 0t0 TCP *:0 (LISTEN)
        node 42 tester 13u IPv4 0x5 0t0 TCP *:65536 (LISTEN)
        node 42 tester 13u IPv4 0x6 0t0 TCP *:65535 (LISTEN)
        """

        XCTAssertEqual(
            LsofParser().parseListeningRecords(output),
            [ListeningPortRecord(pid: 42, command: "node", host: "*", port: 65535)]
        )
    }

    func testBuildsPortOnlyServersFromLocalPortProbeFallback() {
        let scanner = LocalPortProbeScanner(
            ports: [3000, 5173, 8000],
            probe: FixedPortProbe(openPorts: [5173, 8000]),
            timeout: 0.01
        )

        let servers = scanner.scan()

        XCTAssertEqual(servers.map(\.pid), [nil, nil])
        XCTAssertEqual(servers.map(\.displayName), ["localhost:5173", "localhost:8000"])
        XCTAssertEqual(servers.map(\.ports), [[5173], [8000]])
        XCTAssertEqual(servers.map(\.canStop), [false, false])
    }

    func testFallsBackToPortProbeServersWhenLsofIsBlocked() throws {
        let fallback = FixedPortProbeScanner(servers: [
            .probedLocalhost(port: 3000)
        ])
        let scanner = DevServerScanner(
            runner: FailingCommandRunner(),
            fallbackScanner: fallback,
            username: "tester"
        )

        let servers = try scanner.scan()

        XCTAssertEqual(servers, [.probedLocalhost(port: 3000)])
    }

    func testLocalPortProbeRejectsOutOfRangePortsWithoutCrashing() {
        let probe = LocalPortProbe()

        XCTAssertFalse(probe.isListening(host: "127.0.0.1", port: -1, timeout: 0.01))
        XCTAssertFalse(probe.isListening(host: "127.0.0.1", port: 0, timeout: 0.01))
        XCTAssertFalse(probe.isListening(host: "127.0.0.1", port: 65_536, timeout: 0.01))
    }

    func testScannerDoesNotAttachIdentityWhenProcessChangesDuringSnapshot() throws {
        let originalIdentity = identity(for: 4242)
        let replacementIdentity = ProcessIdentity(
            startTimeSeconds: originalIdentity.startTimeSeconds + 1,
            startTimeMicroseconds: 0
        )
        let scanner = DevServerScanner(
            runner: ScannerCommandRunner(),
            identityProvider: SequencedScannerIdentityProvider(
                identities: [originalIdentity, replacementIdentity]
            ),
            username: "tester"
        )

        let server = try XCTUnwrap(scanner.scan().first)

        XCTAssertNil(server.processIdentity)
        XCTAssertFalse(server.canStop)
    }

    func testScannerAttachesIdentityOnlyWhenStableAcrossSnapshot() throws {
        let stableIdentity = identity(for: 4242)
        let scanner = DevServerScanner(
            runner: ScannerCommandRunner(),
            identityProvider: SequencedScannerIdentityProvider(
                identities: [stableIdentity, stableIdentity]
            ),
            username: "tester"
        )

        let server = try XCTUnwrap(scanner.scan().first)

        XCTAssertEqual(server.processIdentity, stableIdentity)
        XCTAssertTrue(server.canStop)
    }
}

private func identity(for pid: Int) -> ProcessIdentity {
    ProcessIdentity(startTimeSeconds: UInt64(pid), startTimeMicroseconds: 0)
}

private struct FixedPortProbe: PortProbing {
    let openPorts: Set<Int>

    func isListening(host: String, port: Int, timeout: TimeInterval) -> Bool {
        openPorts.contains(port)
    }
}

private struct FixedPortProbeScanner: PortProbeScanning {
    let servers: [DevServer]

    func scan() -> [DevServer] {
        servers
    }
}

private struct FailingCommandRunner: CommandRunning {
    func run(_ executable: String, arguments: [String]) throws -> String {
        throw CommandRunnerError.failed(executable: executable, status: 1, output: "operation not permitted")
    }
}

private struct ScannerCommandRunner: CommandRunning {
    func run(_ executable: String, arguments: [String]) throws -> String {
        switch (executable, arguments) {
        case ("/usr/sbin/lsof", let values) where values.contains("-u"):
            return "node 4242 tester 13u IPv4 0x1 0t0 TCP *:5173 (LISTEN)"
        case ("/bin/ps", let values) where values.contains("comm="):
            return "node\n"
        case ("/bin/ps", let values) where values.contains("args="):
            return "node /tmp/example/node_modules/.bin/vite --port 5173\n"
        case ("/usr/sbin/lsof", let values) where values.contains("cwd"):
            return "p4242\nn/tmp/example\n"
        default:
            throw CommandRunnerError.failed(executable: executable, status: 2, output: "unexpected command")
        }
    }
}

private final class SequencedScannerIdentityProvider: ProcessIdentityProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var identities: [ProcessIdentity]

    init(identities: [ProcessIdentity]) {
        self.identities = identities
    }

    func identity(for pid: Int) -> ProcessIdentity? {
        lock.withLock {
            guard identities.isEmpty == false else { return nil }
            return identities.removeFirst()
        }
    }
}
