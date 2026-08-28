import DevServerActivityCore
import Foundation

// These mutable reference types model source-compatible clients that conformed
// before v1.0.1. The protocols must not retroactively require Sendable.
final class LegacyCommandRunner: CommandRunning {
    private var invocationCount = 0

    func run(_ executable: String, arguments: [String]) throws -> String {
        invocationCount += 1
        return ""
    }
}

final class LegacyPortProbe: PortProbing {
    private var invocationCount = 0

    func isListening(host: String, port: Int, timeout: TimeInterval) -> Bool {
        invocationCount += 1
        return false
    }
}

final class LegacyPortProbeScanner: PortProbeScanning {
    private var invocationCount = 0

    func scan() -> [DevServer] {
        invocationCount += 1
        return []
    }
}

func handleLegacyCommandRunnerError(_ error: CommandRunnerError) {
    switch error {
    case .failed:
        break
    }
}

func compileLegacyInitializers() {
    _ = ShellCommandRunner()
    _ = ProcessSnapshot(
        pid: 42,
        commandName: "node",
        commandLine: "node server.js",
        workingDirectory: "/tmp/example"
    )
    _ = DevServer(
        pid: 42,
        displayName: "example",
        kind: .node,
        ports: [3_000],
        hosts: ["127.0.0.1"],
        commandName: "node",
        commandLine: "node server.js",
        workingDirectory: "/tmp/example"
    )
    _ = DevServerScanner(
        runner: LegacyCommandRunner(),
        parser: LsofParser(),
        detector: DevServerDetector(),
        fallbackScanner: LegacyPortProbeScanner(),
        username: "tester"
    )
}
