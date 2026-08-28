import DevServerActivityCore
import Foundation

@MainActor
final class ServerActivityStore: ObservableObject {
    @Published var servers: [DevServer] = []
    @Published var selectedID: DevServer.ID?
    @Published var isRefreshing = false
    @Published var isStopping = false
    @Published var lastRefresh: Date?
    @Published var statusMessage = "Open the app to scan for local servers."
    @Published var errorMessage: String?

    private let service = ServerActivityService()

    var selectedServer: DevServer? {
        guard let selectedID else { return servers.first }
        return servers.first { $0.id == selectedID } ?? servers.first
    }

    func refresh() {
        refresh(clearFeedback: true)
    }

    func stop(server: DevServer, mode: StopMode) {
        guard isStopping == false else { return }
        guard server.canStop else {
            if server.pid == nil {
                errorMessage = "This server was detected by port only, so macOS did not expose a process that can be stopped from here."
            } else {
                errorMessage = "macOS did not expose a stable identity for this process, so it cannot be stopped safely from here."
            }
            statusMessage = "Stop unavailable."
            return
        }

        isStopping = true
        errorMessage = nil

        Task { [weak self, service] in
            do {
                try await service.stop(server: server, mode: mode)
                guard let self else { return }

                let verb = mode == .force ? "Force stopped" : "Stopped"
                statusMessage = "\(verb) \(server.displayName) on port \(server.portSummary)."
                try? await Task.sleep(nanoseconds: 800_000_000)
                isStopping = false
                refresh()
            } catch {
                guard let self else { return }
                isStopping = false
                handleStopError(error)
            }
        }
    }

    private func refresh(clearFeedback: Bool) {
        guard isRefreshing == false else { return }
        isRefreshing = true
        if clearFeedback {
            errorMessage = nil
        }

        Task { [weak self, service] in
            do {
                let freshServers = try await service.scan()
                guard let self else { return }
                apply(freshServers, updateFeedback: clearFeedback)
            } catch {
                guard let self else { return }
                if clearFeedback {
                    errorMessage = error.localizedDescription
                    statusMessage = "Scan failed."
                }
            }
            self?.isRefreshing = false
        }
    }

    private func apply(_ freshServers: [DevServer], updateFeedback: Bool) {
        servers = freshServers
        if let selectedID, freshServers.contains(where: { $0.id == selectedID }) == false {
            self.selectedID = freshServers.first?.id
        } else if selectedID == nil {
            selectedID = freshServers.first?.id
        }

        lastRefresh = Date()
        if updateFeedback {
            statusMessage = freshServers.isEmpty
                ? "No local development servers are running."
                : "Found \(freshServers.count) local server\(freshServers.count == 1 ? "" : "s")."
        }
    }

    private func handleStopError(_ error: Error) {
        if let terminationError = error as? DevServerTerminatorError {
            switch terminationError {
            case .validationFailed, .targetChanged:
                errorMessage = terminationError.localizedDescription
                statusMessage = "Server list refreshed. Nothing was stopped."
                refresh(clearFeedback: false)
            case .invalidPID, .killFailed:
                errorMessage = terminationError.localizedDescription
                statusMessage = "Stop failed."
            }
        } else {
            errorMessage = error.localizedDescription
            statusMessage = "Stop failed."
        }
    }
}

private actor ServerActivityService {
    private let scanner = DevServerScanner()
    private let terminator = DevServerTerminator()

    func scan() throws -> [DevServer] {
        try scanner.scan()
    }

    func stop(server: DevServer, mode: StopMode) throws {
        try terminator.stop(server: server, mode: mode)
    }
}
