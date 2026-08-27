import Foundation

public struct DevServerDetector {
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
        let text = normalized("\(process.commandName) \(process.commandLine)")

        if containsAny(text, ["vite", "node_modules/.bin/vite"]) { return .vite }
        if containsAny(text, ["next-server", "next dev", "/next "]) { return .next }
        if containsAny(text, ["bun "]) || text.hasPrefix("bun ") { return .bun }
        if containsAny(text, ["deno "]) || text.hasPrefix("deno ") { return .deno }
        if containsAny(text, ["python", "uvicorn", "flask", "django", "fastapi"]) { return .python }
        if containsAny(text, ["ruby", "rails"]) { return .ruby }
        if containsAny(text, ["php"]) { return .php }
        if containsAny(text, ["node", "npm", "pnpm", "yarn", "tsx", "ts-node", "webpack", "parcel", "astro", "nuxt", "remix", "svelte"]) {
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

        if kind == .node {
            return containsAny(text, [
                "/documents/",
                "/desktop/",
                "/volumes/",
                "/.trash/",
                "/.codex/",
                "node_modules",
                "next",
                "vite",
                "astro",
                "nuxt",
                "remix",
                "svelte"
            ])
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
