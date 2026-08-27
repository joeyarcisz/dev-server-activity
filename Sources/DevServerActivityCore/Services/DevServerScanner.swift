import Foundation

public struct DevServerScanner {
    private let runner: CommandRunning
    private let parser: LsofParser
    private let detector: DevServerDetector
    private let fallbackScanner: PortProbeScanning
    private let username: String

    public init(
        runner: CommandRunning = ShellCommandRunner(),
        parser: LsofParser = LsofParser(),
        detector: DevServerDetector = DevServerDetector(),
        fallbackScanner: PortProbeScanning = LocalPortProbeScanner(),
        username: String = NSUserName()
    ) {
        self.runner = runner
        self.parser = parser
        self.detector = detector
        self.fallbackScanner = fallbackScanner
        self.username = username
    }

    public func scan() throws -> [DevServer] {
        let output: String
        do {
            output = try runner.run(
                "/usr/sbin/lsof",
                arguments: ["-nP", "-a", "-u", username, "-iTCP", "-sTCP:LISTEN"]
            )
        } catch {
            let fallbackServers = fallbackScanner.scan()
            if fallbackServers.isEmpty == false {
                return fallbackServers
            }

            throw error
        }

        let records = parser.parseListeningRecords(output)
        let snapshots = Dictionary(
            uniqueKeysWithValues: records
                .map(\.pid)
                .uniqued()
                .compactMap { pid in
                    snapshot(for: pid).map { (pid, $0) }
                }
        )

        return detector.detect(records: records, processes: snapshots)
    }

    private func snapshot(for pid: Int) -> ProcessSnapshot? {
        guard
            let commandName = try? runner.run("/bin/ps", arguments: ["-p", "\(pid)", "-o", "comm="]).trimmedNonEmpty,
            let commandLine = try? runner.run("/bin/ps", arguments: ["-p", "\(pid)", "-o", "args="]).trimmedNonEmpty
        else {
            return nil
        }

        let cwdOutput = (try? runner.run("/usr/sbin/lsof", arguments: ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"])) ?? ""
        let workingDirectory = cwdOutput
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first { $0.hasPrefix("n") }
            .map { String($0.dropFirst()) } ?? ""

        return ProcessSnapshot(
            pid: pid,
            commandName: commandName,
            commandLine: commandLine,
            workingDirectory: workingDirectory
        )
    }
}
