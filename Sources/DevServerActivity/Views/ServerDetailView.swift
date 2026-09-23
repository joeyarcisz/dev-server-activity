import AppKit
import DevServerActivityCore
import SwiftUI

struct ServerDetailView: View {
    let server: DevServer
    @ObservedObject var store: ServerActivityStore

    @State private var pendingStop: StopRequest?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let errorMessage = store.errorMessage {
                    StatusBanner(text: errorMessage, systemImage: "exclamationmark.triangle", tint: .orange)
                } else {
                    StatusBanner(text: store.statusMessage, systemImage: "checkmark.circle", tint: .green)
                }

                GroupBox("ADDRESSES") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(server.ports, id: \.self) { port in
                            HStack {
                                Text(verbatim: "http://localhost:\(port)")
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                Spacer()
                                Button {
                                    open(port: port)
                                } label: {
                                    Label("Open", systemImage: "safari")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("PROCESS IDENTITY") {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: "Project", value: server.workingDirectory)
                        DetailRow(label: "PID", value: server.pid.map(String.init) ?? "Unavailable")
                        DetailRow(label: "Name", value: server.commandName)
                        DetailRow(label: "Hosts", value: server.hosts.joined(separator: ", "))
                        DetailRow(label: "Command", value: server.commandLine, monospaced: true)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(24)
        }
        .groupBoxStyle(ActivitySectionStyle())
        .background(ActivityTheme.canvas)
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { pendingStop != nil },
                set: { if $0 == false { pendingStop = nil } }
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
            Button("Cancel", role: .cancel) {
                pendingStop = nil
            }
        } message: {
            if let pendingStop {
                Text("This will stop \(pendingStop.server.displayName) on port \(pendingStop.server.portSummary).")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: server.kind.symbolName)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(ActivityTheme.accent)
                .frame(width: 50, height: 50)
                .background(ActivityTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text("SELECTED SERVER")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(ActivityTheme.accent)

                Text(server.displayName)
                    .font(.system(size: 34, weight: .black))
                    .fontWidth(.condensed)
                    .foregroundStyle(ActivityTheme.bone)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(server.kind.label, systemImage: "tag")
                    Label(":\(server.portSummary)", systemImage: "number")
                    if let pid = server.pid {
                        if server.processIdentity == nil {
                            Label("PID \(pid) unverified", systemImage: "lock.shield")
                        } else {
                            Label("PID \(pid)", systemImage: "cpu")
                        }
                    } else {
                        Label("Port only", systemImage: "lock.shield")
                    }
                }
                .font(.callout)
                .foregroundStyle(ActivityTheme.muted)

                Text("A port number is not an identity. Review the process before stopping it.")
                    .font(.caption)
                    .foregroundStyle(ActivityTheme.muted)
            }

            Spacer()
        }
    }

    private var actionBar: some View {
        HStack {
            Text(store.statusMessage)
                .font(.caption)
                .foregroundStyle(ActivityTheme.muted)
                .lineLimit(1)

            Spacer()

            Button {
                store.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(store.isRefreshing)

            Button {
                pendingStop = StopRequest(server: server, mode: .normal)
            } label: {
                Label("Stop", systemImage: "stop.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(server.canStop == false || store.isStopping)
            .keyboardShortcut(.delete, modifiers: [.command])

            Button(role: .destructive) {
                pendingStop = StopRequest(server: server, mode: .force)
            } label: {
                Label("Force Stop", systemImage: "xmark.octagon")
            }
            .buttonStyle(.bordered)
            .disabled(server.canStop == false || store.isStopping)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(ActivityTheme.surface)
        .overlay(alignment: .top) {
            ActivityTheme.accent.frame(height: 2)
        }
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

private struct DetailRow: View {
    let label: String
    let value: String
    var monospaced = false

    var body: some View {
        GridRow {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(ActivityTheme.muted)
                .frame(width: 88, alignment: .leading)

            Text(value.isEmpty ? "Unknown" : value)
                .font(monospaced ? .system(.callout, design: .monospaced) : .callout)
                .foregroundStyle(ActivityTheme.bone)
                .textSelection(.enabled)
                .lineLimit(monospaced ? 3 : 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct StatusBanner: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(text)
                .font(.callout)
                .foregroundStyle(ActivityTheme.bone)
            Spacer()
        }
        .padding(12)
        .background(ActivityTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ActivityTheme.hairline))
    }
}

private struct ActivitySectionStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            configuration.label
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(ActivityTheme.accent)
            configuration.content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ActivityTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ActivityTheme.hairline))
    }
}
