import Combine
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
                .padding(.horizontal, 18)
                .padding(.vertical, 18)

                Rectangle()
                    .fill(ActivityTheme.hairline)
                    .frame(height: 1)

                List(filteredServers, selection: $store.selectedID) { server in
                    ServerRowView(server: server)
                        .tag(server.id)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .overlay {
                    if filteredServers.isEmpty {
                        EmptySidebarView(hasServers: store.servers.isEmpty == false)
                    }
                }
            }
            .background(ActivityTheme.sidebar)
            .navigationSplitViewColumnWidth(min: 280, ideal: 330, max: 420)
        } detail: {
            if let server = store.selectedServer {
                ServerDetailView(server: server, store: store)
            } else {
                EmptyDetailView(refresh: store.refresh)
            }
        }
        .frame(minWidth: 920, minHeight: 560)
        .preferredColorScheme(.dark)
        .tint(ActivityTheme.accent)
        .overlay(alignment: .top) {
            ActivityTheme.accent.frame(height: 3).allowsHitTesting(false)
        }
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
        VStack(alignment: .leading, spacing: 9) {
            Text("DEV SERVER ACTIVITY")
                .font(.system(size: 11, weight: .heavy))
                .tracking(2)
                .foregroundStyle(ActivityTheme.accent)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(count.formatted())
                    .font(.system(size: 42, weight: .black))
                    .fontWidth(.condensed)
                    .foregroundStyle(count == 0 ? ActivityTheme.bone : ActivityTheme.accent)

                Text(count == 1 ? "SERVER RUNNING" : "SERVERS RUNNING")
                    .font(.system(size: 14, weight: .heavy))
                    .fontWidth(.condensed)
                    .foregroundStyle(ActivityTheme.bone)

                Spacer(minLength: 0)

                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text("See what is still listening.")
                .font(.caption)
                .foregroundStyle(ActivityTheme.muted)

            Text(lastRefreshText)
                .font(.caption2)
                .foregroundStyle(ActivityTheme.muted)
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
                .foregroundStyle(ActivityTheme.accent)
            Text(hasServers ? "No Matches" : "No Servers Found")
                .font(.system(.headline, design: .default, weight: .heavy))
                .fontWidth(.condensed)
                .foregroundStyle(ActivityTheme.bone)
            Text(hasServers ? "Clear the filter to see running servers." : "No local dev servers found in this scan.")
                .font(.caption)
                .foregroundStyle(ActivityTheme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 220)
        }
        .padding()
    }
}

private struct EmptyDetailView: View {
    let refresh: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "network.slash")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(ActivityTheme.accent)
            Text("SEE WHAT IS STILL LISTENING")
                .font(.system(size: 30, weight: .black))
                .fontWidth(.condensed)
                .foregroundStyle(ActivityTheme.bone)
            Text("Select a server to review its project, command, PID, and ports before you stop it.")
                .foregroundStyle(ActivityTheme.muted)
                .multilineTextAlignment(.center)
            Button(action: refresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ActivityTheme.canvas)
    }
}
