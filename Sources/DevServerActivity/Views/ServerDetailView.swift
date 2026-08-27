import AppKit
import DevServerActivityCore
import SwiftUI

struct ServerDetailView: View {
    let server: DevServer
    @ObservedObject var store: ServerActivityStore

    @State private var confirmStopMode: StopMode?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let errorMessage = store.errorMessage {
                    StatusBanner(text: errorMessage, systemImage: "exclamationmark.triangle", tint: .orange)
                } else {
                    StatusBanner(text: store.statusMessage, systemImage: "checkmark.circle", tint: .green)
                }

                GroupBox("Addresses") {
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

                GroupBox("Process") {
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
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { confirmStopMode != nil },
                set: { if $0 == false { confirmStopMode = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let confirmStopMode {
                Button(confirmStopMode == .force ? "Force Stop Server" : "Stop Server", role: .destructive) {
                    store.stopSelected(mode: confirmStopMode)
                    self.confirmStopMode = nil
                }
            }
            Button("Cancel", role: .cancel) {
                confirmStopMode = nil
            }
        } message: {
            Text("This will stop \(server.displayName) on port \(server.portSummary).")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: server.kind.symbolName)
                .font(.system(size: 30))
                .foregroundStyle(server.kind.tint)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 6) {
                Text(server.displayName)
                    .font(.largeTitle.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(server.kind.label, systemImage: "tag")
                    Label(":\(server.portSummary)", systemImage: "number")
                    if let pid = server.pid {
                        Label("PID \(pid)", systemImage: "cpu")
                    } else {
                        Label("Port only", systemImage: "lock.shield")
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var actionBar: some View {
        HStack {
            Text(store.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button {
                store.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }

            Button {
                confirmStopMode = .normal
            } label: {
                Label("Stop", systemImage: "stop.circle")
            }
            .disabled(server.canStop == false)
            .keyboardShortcut(.delete, modifiers: [.command])

            Button(role: .destructive) {
                confirmStopMode = .force
            } label: {
                Label("Force Stop", systemImage: "xmark.octagon")
            }
            .disabled(server.canStop == false)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private var confirmationTitle: String {
        guard let confirmStopMode else { return "Stop Server?" }
        return confirmStopMode == .force ? "Force Stop Server?" : "Stop Server?"
    }

    private func open(port: Int) {
        guard let url = URL(string: "http://localhost:\(port)") else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    var monospaced = false

    var body: some View {
        GridRow {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)

            Text(value.isEmpty ? "Unknown" : value)
                .font(monospaced ? .system(.callout, design: .monospaced) : .callout)
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
            Spacer()
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
