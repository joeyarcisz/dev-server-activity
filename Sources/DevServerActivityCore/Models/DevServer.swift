import Foundation

public enum DevServerKind: String, CaseIterable, Equatable, Hashable, Sendable {
    case vite
    case next
    case node
    case python
    case ruby
    case php
    case bun
    case deno
    case other

    public var label: String {
        switch self {
        case .vite: "Vite"
        case .next: "Next"
        case .node: "Node"
        case .python: "Python"
        case .ruby: "Ruby"
        case .php: "PHP"
        case .bun: "Bun"
        case .deno: "Deno"
        case .other: "Server"
        }
    }
}

public struct DevServer: Identifiable, Equatable, Hashable, Sendable {
    public var id: String {
        if let pid {
            if let processIdentity {
                return "pid-\(pid)-\(processIdentity.startTimeSeconds)-\(processIdentity.startTimeMicroseconds)"
            }
            return "pid-\(pid)-unverified"
        }

        return "port-\(primaryPort ?? 0)"
    }

    public let pid: Int?
    public let processIdentity: ProcessIdentity?
    public let displayName: String
    public let kind: DevServerKind
    public let ports: [Int]
    public let hosts: [String]
    public let commandName: String
    public let commandLine: String
    public let workingDirectory: String

    public init(
        pid: Int?,
        displayName: String,
        kind: DevServerKind,
        ports: [Int],
        hosts: [String],
        commandName: String,
        commandLine: String,
        workingDirectory: String
    ) {
        self.init(
            pid: pid,
            processIdentity: nil,
            displayName: displayName,
            kind: kind,
            ports: ports,
            hosts: hosts,
            commandName: commandName,
            commandLine: commandLine,
            workingDirectory: workingDirectory
        )
    }

    public init(
        pid: Int?,
        processIdentity: ProcessIdentity?,
        displayName: String,
        kind: DevServerKind,
        ports: [Int],
        hosts: [String],
        commandName: String,
        commandLine: String,
        workingDirectory: String
    ) {
        self.pid = pid
        self.processIdentity = processIdentity
        self.displayName = displayName
        self.kind = kind
        self.ports = ports
        self.hosts = hosts
        self.commandName = commandName
        self.commandLine = commandLine
        self.workingDirectory = workingDirectory
    }

    public var canStop: Bool {
        pid != nil && processIdentity != nil
    }

    public var primaryPort: Int? {
        ports.first
    }

    public var primaryURLString: String? {
        guard let primaryPort else { return nil }
        return "http://localhost:\(primaryPort)"
    }

    public var portSummary: String {
        ports.map(String.init).joined(separator: ", ")
    }

    public static func probedLocalhost(port: Int) -> DevServer {
        DevServer(
            pid: nil,
            processIdentity: nil,
            displayName: "localhost:\(port)",
            kind: .other,
            ports: [port],
            hosts: ["127.0.0.1"],
            commandName: "Port probe",
            commandLine: "Listening on localhost:\(port)",
            workingDirectory: ""
        )
    }
}
