import Foundation

public struct DevServerDetector: Sendable {
    public init() {}

    public func detect(records: [ListeningPortRecord], processes: [Int: ProcessSnapshot]) -> [DevServer] {
        let recordsByPID = Dictionary(grouping: records, by: \.pid)

        return recordsByPID.compactMap { pid, records -> DevServer? in
            guard let process = processes[pid] else { return nil }
            let kind = classify(process: process)
            guard isLikelyLocalServer(kind: kind, process: process) else { return nil }

            let ports = Array(Set(records.map(\.port))).sorted()
            let hosts = Array(Set(records.map(\.host))).sorted()

            return DevServer(
                pid: pid,
                processIdentity: process.processIdentity,
                displayName: displayName(for: process),
                kind: kind,
                ports: ports,
                hosts: hosts,
                commandName: process.commandName,
                commandLine: process.commandLine,
                workingDirectory: process.workingDirectory
            )
        }
        .sorted { lhs, rhs in
            switch (lhs.primaryPort, rhs.primaryPort) {
            case let (left?, right?) where left != right:
                return left < right
            default:
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
        }
    }

    private func classify(process: ProcessSnapshot) -> DevServerKind {
        let executable = (process.commandName as NSString).lastPathComponent.lowercased()
        if executable == "next-server" || executable.hasPrefix("next-server (") { return .next }
        if executable == "bun" { return .bun }
        if executable == "deno" { return .deno }
        if executable.range(of: #"^python([0-9]+(\.[0-9]+)*)?$"#, options: .regularExpression) != nil
            || ["uvicorn", "flask", "django-admin", "fastapi"].contains(executable) { return .python }
        if executable.range(of: #"^ruby([0-9]+(\.[0-9]+)*)?$"#, options: .regularExpression) != nil
            || executable == "rails" { return .ruby }
        if executable.range(of: #"^php([0-9]+(\.[0-9]+)*)?$"#, options: .regularExpression) != nil { return .php }

        // Match the runtime, not arbitrary project names or arguments of another app.
        let nodeCommands = ["node", "nodejs", "npm", "pnpm", "yarn", "tsx", "ts-node"]
        if nodeCommands.contains(executable) || ["npm ", "pnpm ", "yarn "].contains(where: executable.hasPrefix) {
            let commandLine = process.commandLine.lowercased()
            if commandLine.range(of: #"(^|[/\s])vite(\.js)?(\s|$)"#, options: .regularExpression) != nil { return .vite }
            if commandLine.range(of: #"(^|[/\s])(next|next-server)(\s|$)"#, options: .regularExpression) != nil { return .next }
            return .node
        }

        return .other
    }

    private func isLikelyLocalServer(kind: DevServerKind, process: ProcessSnapshot) -> Bool {
        guard kind != .other else { return false }

        let text = normalized("\(process.commandName) \(process.commandLine) \(process.workingDirectory)")
        if containsAny(text, [
            "/system/library/",
            "/applications/tailscale.app/",
            "/library/application support/adobe/"
        ]) {
            return false
        }

        return true
    }

    private func displayName(for process: ProcessSnapshot) -> String {
        let trimmedFolder = process.workingDirectory.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmedFolder.isEmpty == false {
            let url = URL(fileURLWithPath: process.workingDirectory)
            let last = url.lastPathComponent
            if last.isEmpty == false {
                return last
            }
        }

        return process.commandName
    }

    private func normalized(_ value: String) -> String {
        value.lowercased()
    }

    private func containsAny(_ text: String, _ fragments: [String]) -> Bool {
        fragments.contains { text.contains($0) }
    }
}
