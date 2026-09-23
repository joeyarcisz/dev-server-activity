import Combine
import DevServerActivityCore
import SwiftUI

@MainActor
struct ContentView: View {
    @StateObject private var store: ServerActivityStore
    @State private var searchText: String
    @State private var autoRefresh = true
    private let automaticScanning: Bool
    private let refreshTimer = Timer.publish(every: 6, on: .main, in: .common).autoconnect()

    init(store: ServerActivityStore? = nil, automaticScanning: Bool = true, initialSearch: String = "") {
        _store = StateObject(wrappedValue: store ?? ServerActivityStore())
        _searchText = State(initialValue: initialSearch)
        self.automaticScanning = automaticScanning
    }

    private var filteredServers: [DevServer] {
        guard !searchText.isEmpty else { return store.servers }
        return store.servers.filter { server in
            [server.displayName, server.kind.label, server.portSummary, server.commandName,
             server.commandLine, server.workingDirectory]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    private var visibleSelection: DevServer? {
        filteredServers.first { $0.id == store.selectedID } ?? filteredServers.first
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "waveform.path")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(ActivityTheme.accent)
                    Text("Local servers")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text(store.servers.count.formatted())
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.primary.opacity(0.06), in: Capsule())
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 12)

                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Project, process, or port", text: $searchText)
                        .textFieldStyle(.plain)
                        .accessibilityLabel("Search servers")
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear search")
                        .accessibilityLabel("Clear search")
                    }
                }
                .font(.system(size: 12))
                .padding(9)
                .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

                List(filteredServers, selection: $store.selectedID) { server in
                    ServerRowView(server: server).tag(server.id)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .overlay {
                    if filteredServers.isEmpty {
                        VStack(spacing: 8) {
                            Text(searchText.isEmpty ? "No servers to show" : "No matching servers")
                                .font(.callout.weight(.medium))
                            if !searchText.isEmpty {
                                Button("Clear search") { searchText = "" }
                                    .buttonStyle(.link)
                            }
                        }
                        .foregroundStyle(.secondary)
                        .padding()
                    }
                }

                Divider()
                HStack(spacing: 7) {
                    if store.isRefreshing {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: store.errorMessage == nil ? "arrow.clockwise" : "exclamationmark.circle")
                    }
                    Text(scanStatus).lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "laptopcomputer")
                        .help("Processes owned by your macOS account")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .frame(minWidth: 270, idealWidth: 292, maxWidth: 320)

            ZStack {
                if let server = visibleSelection {
                    ServerDetailView(server: server, store: store)
                } else {
                    ServerEmptyView(
                        error: store.errorMessage,
                        isRefreshing: store.isRefreshing,
                        hasFilter: !searchText.isEmpty,
                        hasScanned: store.lastRefresh != nil,
                        refresh: store.refresh,
                        clearSearch: { searchText = "" }
                    )
                }
            }
            .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 880, idealWidth: 1080, maxWidth: .infinity,
               minHeight: 580, idealHeight: 720, maxHeight: .infinity)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                HStack(spacing: 8) {
                    Text("Auto refresh").font(.system(size: 12))
                    Toggle("Auto refresh", isOn: $autoRefresh)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .accessibilityLabel("Auto refresh")
                }
                .fixedSize()
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .help("Refresh the server list every six seconds")
                Button(action: store.refresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isRefreshing)
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
        .onAppear { if automaticScanning { store.refresh() } }
        .onChange(of: filteredServers.map(\.id)) { _, _ in
            if !filteredServers.contains(where: { $0.id == store.selectedID }) {
                store.selectedID = filteredServers.first?.id
            }
        }
        .onReceive(refreshTimer) { _ in
            guard automaticScanning, autoRefresh, !store.isRefreshing else { return }
            store.refresh()
        }
    }

    private var scanStatus: String {
        if store.isRefreshing { return "Checking this Mac…" }
        if store.errorMessage != nil { return "Scan needs attention" }
        guard let date = store.lastRefresh else { return "Ready to scan" }
        return "Updated \(date.formatted(date: .omitted, time: .shortened))"
    }
}

private struct ServerEmptyView: View {
    let error: String?
    let isRefreshing: Bool
    let hasFilter: Bool
    let hasScanned: Bool
    let refresh: () -> Void
    let clearSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: error != nil ? "exclamationmark.circle" : hasFilter ? "magnifyingglass" : "network")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(ActivityTheme.accent)
                .padding(.bottom, 6)
            Text(title)
                .font(.system(size: 28, weight: .semibold))
                .tracking(-0.6)
            Text(description)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            if isRefreshing {
                ProgressView().controlSize(.small)
            } else {
                Button(hasFilter ? "Clear search" : "Scan again", action: hasFilter ? clearSearch : refresh)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: 350, alignment: .leading)
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ActivityTheme.canvas)
    }

    private var title: String {
        if error != nil { return "The scan needs a second look." }
        if isRefreshing { return "Checking what’s listening." }
        if hasFilter { return "Nothing matches that search." }
        return hasScanned ? "No dev servers found." : "Know what’s still running."
    }

    private var description: String {
        if let error { return error }
        if hasFilter { return "Try a project name, process, or port. Clear the search to see the full list." }
        return "Start a local development server, then check here. You’ll see its project and process before deciding what to stop."
    }
}
