import DevServerActivityCore
import SwiftUI

struct ServerRowView: View {
    let server: DevServer

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: server.kind.symbolName)
                .foregroundStyle(server.kind.tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(server.displayName)
                    .lineLimit(1)

                Text("\(server.kind.label)  :\(server.portSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(server.workingDirectory)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }
}
