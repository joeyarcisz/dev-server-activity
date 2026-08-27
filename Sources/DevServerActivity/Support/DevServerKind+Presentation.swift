import DevServerActivityCore
import SwiftUI

extension DevServerKind {
    var symbolName: String {
        switch self {
        case .vite: "bolt.fill"
        case .next: "arrowtriangle.right.circle.fill"
        case .node: "hexagon.fill"
        case .python: "chevron.left.forwardslash.chevron.right"
        case .ruby: "diamond.fill"
        case .php: "curlybraces"
        case .bun: "shippingbox.fill"
        case .deno: "terminal.fill"
        case .other: "network"
        }
    }

    var tint: Color {
        switch self {
        case .vite: .orange
        case .next: .primary
        case .node: .green
        case .python: .blue
        case .ruby: .red
        case .php: .indigo
        case .bun: .brown
        case .deno: .mint
        case .other: .secondary
        }
    }
}
