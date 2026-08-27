import DevServerActivityCore
import SwiftUI

struct ContentView: View {
    @StateObject private var store = ServerActivityStore()
    @State private var searchText = ""
    @State private var autoRefresh = true

    private let refreshTimer = Timer.publish(every: 6, on: .main, in: .common).autoconnect()

    private var filteredServers: [DevServer] {
        guard searchText.isEmpty == false else { return store.servers }
        let query = searchText.lowercased()
        return store.servers.filter { server in
            [
                server.displayName,
                server.kind.label,
                server.portSummary,
                server.commandName,
                server.commandLine,
                server.workingDirectory
            ]
            .joined(separator: " ")
            .lowercased()
            .contains(query)
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                ServerSummaryBar(
                    count: store.servers.count,
                    isRefreshing: store.isRefreshing,
                    lastRefresh: store.lastRefresh
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Divider()

                List(filteredServers, selection: $store.selectedID) { server in
                    ServerRowView(server: server)
                        .tag(server.id)
                }
                .listStyle(.sidebar)
                .overlay {
                    if filteredServers.isEmpty {
                        EmptySidebarView(hasServers: store.servers.isEmpty == false)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 330, max: 420)
        } detail: {
            if let server = store.selectedServer {
                ServerDetailView(server: server, store: store)
            } else {
                EmptyDetailView(refresh: store.refresh)
            }
        }
        .frame(minWidth: 920, minHeight: 560)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Filter servers")
        .toolbar {
            ToolbarItemGroup {
                Toggle(isOn: $autoRefresh) {
                    Label("Auto Refresh", systemImage: autoRefresh ? "bolt.circle.fill" : "bolt.slash.circle")
                }
                .toggleStyle(.button)

                Button(action: store.refresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isRefreshing)
            }
        }
        .onAppear(perform: store.refresh)
        .onReceive(refreshTimer) { _ in
            guard autoRefresh, store.isRefreshing == false else { return }
            store.refresh()
        }
    }
}

private struct ServerSummaryBar: View {
    let count: Int
    let isRefreshing: Bool
    let lastRefresh: Date?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "network")
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) Running")
                    .font(.headline)
                Text(lastRefreshText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isRefreshing {
                ProgressView()
                    .scaleEffect(0.65)
                    .frame(width: 18, height: 18)
            }
        }
    }

    private var lastRefreshText: String {
        guard let lastRefresh else { return "Not scanned yet" }
        return "Updated \(lastRefresh.formatted(date: .omitted, time: .shortened))"
    }
}

private struct EmptySidebarView: View {
    let hasServers: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: hasServers ? "magnifyingglass" : "powerplug")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(hasServers ? "No Matches" : "No Servers")
                .font(.headline)
            Text(hasServers ? "Clear the filter to see running servers." : "Nothing is listening as a local dev server right now.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 220)
        }
        .padding()
    }
}

private struct EmptyDetailView: View {
    let refresh: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Server Selected", systemImage: "network.slash")
        } description: {
            Text("Refresh to scan for local dev servers.")
        } actions: {
            Button(action: refresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }
}
