import DevServerActivityCore
import Foundation

@MainActor
final class ServerActivityStore: ObservableObject {
    @Published var servers: [DevServer] = []
    @Published var selectedID: DevServer.ID?
    @Published var isRefreshing = false
    @Published var lastRefresh: Date?
    @Published var statusMessage = "Open the app to scan for local servers."
    @Published var errorMessage: String?

    private let scanner = DevServerScanner()
    private let terminator = DevServerTerminator()

    var selectedServer: DevServer? {
        guard let selectedID else { return servers.first }
        return servers.first { $0.id == selectedID } ?? servers.first
    }

    func refresh() {
        isRefreshing = true
        errorMessage = nil

        do {
            let freshServers = try scanner.scan()
            servers = freshServers
            if let selectedID, freshServers.contains(where: { $0.id == selectedID }) == false {
                self.selectedID = freshServers.first?.id
            } else if selectedID == nil {
                selectedID = freshServers.first?.id
            }

            lastRefresh = Date()
            statusMessage = freshServers.isEmpty
                ? "No local development servers are running."
                : "Found \(freshServers.count) local server\(freshServers.count == 1 ? "" : "s")."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Scan failed."
        }

        isRefreshing = false
    }

    func stopSelected(mode: StopMode) {
        guard let selectedServer else { return }
        guard selectedServer.pid != nil else {
            errorMessage = "This server was detected by port only, so macOS did not expose a process that can be stopped from here."
            statusMessage = "Stop unavailable."
            return
        }

        do {
            try terminator.stop(server: selectedServer, mode: mode)
            let verb = mode == .force ? "Force stopped" : "Stopped"
            statusMessage = "\(verb) \(selectedServer.displayName) on port \(selectedServer.portSummary)."
            errorMessage = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.refresh()
            }
        } catch {
            if let terminationError = error as? DevServerTerminatorError {
                switch terminationError {
                case .validationFailed, .targetChanged:
                    refresh()
                    errorMessage = terminationError.localizedDescription
                    statusMessage = "Server list refreshed. Nothing was stopped."
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
}
