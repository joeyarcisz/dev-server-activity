import DevServerActivityCore
import SwiftUI

struct ServerRowView: View {
    let server: DevServer

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: server.kind.symbolName)
                .foregroundStyle(ActivityTheme.accent)
                .frame(width: 26, height: 26)
                .background(ActivityTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(server.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ActivityTheme.bone)
                    .lineLimit(1)

                Text("\(server.kind.label)  ·  :\(server.portSummary)")
                    .font(.caption)
                    .foregroundStyle(ActivityTheme.muted)
                    .lineLimit(1)

                Text(server.workingDirectory)
                    .font(.caption2)
                    .foregroundStyle(ActivityTheme.muted)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 5)
        .accessibilityLabel("\(server.displayName), \(server.kind.label), port \(server.portSummary), project \(server.workingDirectory)")
    }
}
