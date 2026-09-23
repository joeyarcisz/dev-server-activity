import AppKit
import DevServerActivityCore
import SwiftUI

struct ServerDetailView: View {
    let server: DevServer
    @ObservedObject var store: ServerActivityStore
    @State private var pendingStop: StopRequest?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                if let error = store.errorMessage {
                    Label {
                        Text(error).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Project folder")
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        Text(server.workingDirectory.isEmpty ? "Unavailable for this listener" : server.workingDirectory)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel(server.ports.count == 1 ? "Local address" : "Local addresses")
                    ForEach(server.ports, id: \.self) { port in
                        HStack(spacing: 12) {
                            Text(verbatim: "localhost:\(port)")
                                .font(.system(size: 17, weight: .medium, design: .monospaced))
                                .textSelection(.enabled)
                            Spacer(minLength: 12)
                            Button {
                                open(port: port)
                            } label: {
                                Label("Open", systemImage: "arrow.up.right")
                            }
                            .help(Text(verbatim: "Open http://localhost:\(port) in your browser"))
                            .controlSize(.regular)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(ActivityTheme.well, in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                Rectangle().fill(ActivityTheme.rule).frame(height: 1)

                VStack(alignment: .leading, spacing: 16) {
                    sectionLabel("Process details")
                    ProcessField(label: "Process", value: server.commandName)
                    ProcessField(label: "PID", value: server.pid.map(String.init) ?? "Unavailable")
                    ProcessField(label: "Hosts", value: server.hosts.joined(separator: ", "))

                    VStack(alignment: .leading, spacing: 9) {
                        Text("Command")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text(server.commandLine.isEmpty ? "Unavailable" : server.commandLine)
                            .font(.system(size: 12, design: .monospaced))
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(ActivityTheme.well, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 840, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .background(ActivityTheme.canvas)
        .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { pendingStop != nil },
                set: { if !$0 { pendingStop = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pendingStop {
                Button(pendingStop.mode == .force ? "Force Stop Server" : "Stop Server", role: .destructive) {
                    let request = pendingStop
                    self.pendingStop = nil
                    store.stop(server: request.server, mode: request.mode)
                }
            }
            Button("Cancel", role: .cancel) { pendingStop = nil }
        } message: {
            if let pendingStop {
                Text("This will stop \(pendingStop.server.displayName) on port \(pendingStop.server.portSummary).")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: server.kind.symbolName)
                    .foregroundStyle(.secondary)
                Text(server.kind.label)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("Listening")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .font(.system(size: 12))

            Text(server.displayName)
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.7)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            Text(server.canStop
                 ? "Review this server before you stop it."
                 : "This listener is visible, but its process could not be verified.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actionBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(ActivityTheme.rule).frame(height: 1)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.isStopping ? "Stopping server…" : server.canStop ? "Done with this server?" : "Stop unavailable")
                        .font(.system(size: 12, weight: .medium))
                    Text(server.canStop ? "Only this process will be stopped." : "Process identity is required.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button(role: .destructive) {
                    pendingStop = StopRequest(server: server, mode: .force)
                } label: {
                    Text("Force Stop…")
                }
                .buttonStyle(.bordered)
                .help("End this process immediately, without allowing it to save state")
                .disabled(!server.canStop || store.isStopping)

                Button {
                    pendingStop = StopRequest(server: server, mode: .normal)
                } label: {
                    Label("Stop Server…", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(ActivityTheme.stop)
                .help("Ask this process to stop. You will confirm the selected server first.")
                .disabled(!server.canStop || store.isStopping)
                .keyboardShortcut(.delete, modifiers: [.command])
            }
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .background(ActivityTheme.canvas)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private var confirmationTitle: String {
        guard let pendingStop else { return "Stop Server?" }
        return pendingStop.mode == .force ? "Force Stop Server?" : "Stop Server?"
    }

    private func open(port: Int) {
        guard let url = URL(string: "http://localhost:\(port)") else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct StopRequest {
    let server: DevServer
    let mode: StopMode
}

private struct ProcessField: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value.isEmpty ? "Unavailable" : value)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
