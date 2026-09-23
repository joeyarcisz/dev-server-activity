import Darwin
import Foundation
import XCTest
@testable import DevServerActivityCore

final class LiveServerTests: XCTestCase {
    func testScansAndStopsAnOwnedDisposableHTTPServer() throws {
        try exerciseServer(mode: .normal)
    }

    func testScansAndForceStopsAnOwnedDisposableHTTPServer() throws {
        try exerciseServer(mode: .force)
    }

    func testScansPlainNodeServerOutsideConventionalProjectFolders() throws {
        guard let node = try? ShellCommandRunner().run("/usr/bin/which", arguments: ["node"]).trimmedNonEmpty else {
            throw XCTSkip("Node is not installed; Python integration tests still cover the real stop path.")
        }
        try exerciseServer(mode: .normal, executable: node, arguments: ["-e", """
        const server = require('http').createServer((req, res) => res.end('audit fixture'));
        server.listen(0, '127.0.0.1', () => console.log(server.address().port));
        """], expectedKind: .node)
    }

    private func exerciseServer(
        mode: StopMode,
        executable: String = "/usr/bin/python3",
        arguments: [String]? = nil,
        expectedKind: DevServerKind = .python
    ) throws {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments ?? ["-u", "-c", """
        import http.server
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), http.server.SimpleHTTPRequestHandler)
        print(server.server_address[1], flush=True)
        server.serve_forever()
        """]
        process.currentDirectoryURL = URL(fileURLWithPath: "/tmp")
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        defer {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
        }

        var descriptor = pollfd(fd: output.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0)
        guard poll(&descriptor, 1, 5_000) > 0 else {
            XCTFail("Disposable server did not report its port within five seconds.")
            return
        }
        let portText = String(data: output.fileHandleForReading.availableData, encoding: .utf8)
        let port = try XCTUnwrap(portText.flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) })
        let pid = Int(process.processIdentifier)
        let server = try XCTUnwrap(DevServerScanner().scan().first { $0.pid == pid })
        XCTAssertEqual(server.kind, expectedKind)
        XCTAssertTrue(server.ports.contains(port))
        XCTAssertTrue(server.canStop)
        XCTAssertTrue(LocalPortProbe().isListening(host: "127.0.0.1", port: port, timeout: 1))

        // Exercise the real identity, ps, lsof and signal path, never a user's process.
        try DevServerTerminator().stop(server: server, mode: mode)
        let deadline = Date().addingTimeInterval(3)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        XCTAssertFalse(process.isRunning)
        XCTAssertFalse(LocalPortProbe().isListening(host: "127.0.0.1", port: port, timeout: 0.2))
    }
}
