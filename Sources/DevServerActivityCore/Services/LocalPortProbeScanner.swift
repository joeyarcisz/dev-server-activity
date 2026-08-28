import Foundation
import Network

public protocol PortProbing {
    func isListening(host: String, port: Int, timeout: TimeInterval) -> Bool
}

public protocol PortProbeScanning {
    func scan() -> [DevServer]
}

public struct LocalPortProbeScanner: PortProbeScanning {
    private let ports: [Int]
    private let probe: PortProbing
    private let timeout: TimeInterval

    public init(
        ports: [Int] = CommonDevPorts.ports,
        probe: PortProbing = LocalPortProbe(),
        timeout: TimeInterval = 0.2
    ) {
        self.ports = ports
        self.probe = probe
        self.timeout = timeout
    }

    public func scan() -> [DevServer] {
        ports
            .filter { probe.isListening(host: "127.0.0.1", port: $0, timeout: timeout) }
            .map(DevServer.probedLocalhost(port:))
    }
}

public enum CommonDevPorts {
    public static let ports: [Int] = Array(Set([
        3000, 3001, 3002, 3003, 3004, 3005,
        3333,
        4000, 4001, 4173, 4200, 4321,
        5000, 5001, 5173, 5174, 5175, 5176, 5177, 5178, 5179,
        7000, 7070,
        8000, 8001, 8002, 8080, 8081, 8082, 8083, 8084, 8090,
        8787, 8888, 9000, 9292
    ])).sorted()
}

public struct LocalPortProbe: PortProbing, Sendable {
    public init() {}

    public func isListening(host: String, port: Int, timeout: TimeInterval) -> Bool {
        guard
            (1...65_535).contains(port),
            let nwPort = NWEndpoint.Port(rawValue: UInt16(port))
        else {
            return false
        }

        let queue = DispatchQueue(label: "DevServerActivity.LocalPortProbe.\(port)")
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        let group = DispatchGroup()
        let state = PortProbeState()

        group.enter()
        connection.stateUpdateHandler = { connectionState in
            switch connectionState {
            case .ready:
                connection.cancel()
                if state.finish(true) {
                    group.leave()
                }
            case .failed, .cancelled:
                if state.finish(false) {
                    group.leave()
                }
            default:
                break
            }
        }

        connection.start(queue: queue)

        if group.wait(timeout: .now() + timeout) == .timedOut {
            connection.cancel()
            if state.finish(false) {
                group.leave()
            }
        }

        return state.isListening
    }
}

private final class PortProbeState: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    private var listening = false

    var isListening: Bool {
        lock.withLock { listening }
    }

    func finish(_ value: Bool) -> Bool {
        lock.withLock {
            guard completed == false else { return false }
            completed = true
            listening = value
            return true
        }
    }
}
