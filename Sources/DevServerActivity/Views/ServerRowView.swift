import DevServerActivityCore
import SwiftUI

struct ServerRowView: View {
    let server: DevServer

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: server.kind.symbolName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(server.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let port = server.primaryPort {
                        Text(verbatim: ":\(port)" + (server.ports.count > 1 ? " +\(server.ports.count - 1)" : ""))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                }
                Text(server.workingDirectory.isEmpty
                     ? (server.pid == nil ? "Port only · process unavailable" : "Project folder unavailable")
                     : (server.workingDirectory as NSString).abbreviatingWithTildeInPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 8)
        .help("\(server.kind.label) · \(server.workingDirectory) · ports \(server.portSummary)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(server.displayName), \(server.kind.label), ports \(server.portSummary), project \(server.workingDirectory)")
    }
}
