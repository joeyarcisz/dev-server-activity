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

public struct LocalPortProbe: PortProbing {
    public init() {}

    public func isListening(host: String, port: Int, timeout: TimeInterval) -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return false
        }

        let queue = DispatchQueue(label: "DevServerActivity.LocalPortProbe.\(port)")
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        let group = DispatchGroup()
        let lock = NSLock()
        var completed = false
        var isListening = false

        func finish(_ value: Bool) {
            lock.lock()
            defer { lock.unlock() }
            guard completed == false else { return }
            completed = true
            isListening = value
            group.leave()
        }

        group.enter()
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.cancel()
                finish(true)
            case .failed, .cancelled:
                finish(false)
            default:
                break
            }
        }

        connection.start(queue: queue)

        if group.wait(timeout: .now() + timeout) == .timedOut {
            connection.cancel()
            finish(false)
        }

        return isListening
    }
}
