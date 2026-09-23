import AppKit
import DevServerActivityCore
import SwiftUI

// Synthetic fixtures in a separate development app. No automatic scanning.
// Close the window to quit. Never confirm a stop while inspecting a preview.
@main
@MainActor
struct PreviewApp: App {
    @NSApplicationDelegateAdaptor(PreviewDelegate.self) private var delegate
    @StateObject private var store = makeStore()
    private static var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }
    private static var scenario: String { info["PreviewScenario"] as? String ?? "populated" }

    var body: some Scene {
        WindowGroup("Kill the Zombie Servers") {
            ContentView(
                store: store, automaticScanning: false,
                initialSearch: Self.scenario == "filtered" ? "nothing-matches" : ""
            )
        }
        .defaultSize(
            width: Self.info["PreviewSize"] as? String == "min" ? 880 : 1080,
            height: Self.info["PreviewSize"] as? String == "min" ? 580 : 720
        )
        .windowResizability(.contentMinSize)
        .commands { CommandGroup(replacing: .newItem) {} }
    }

    private static func makeStore() -> ServerActivityStore {
        let store = ServerActivityStore()
        let names: [(String, DevServerKind, Int, String)] = [
            ("website", .vite, 5173, "/Projects/field-notes/website"),
            ("api", .node, 3000, "/Projects/field-notes/api"),
            ("studio", .next, 3001, "/Projects/studio"),
            ("docs", .vite, 4321, "/Projects/documentation"),
            ("preview", .bun, 8080, "/Projects/experiments/preview"),
            ("web", .next, 5174, "/Projects/client-portal/worktrees/search-ui/apps/web")
        ]
        store.servers = names.enumerated().map { index, value in
            let command: String
            switch value.1 {
            case .next: command = "node ./node_modules/next/dist/bin/next dev"
            case .bun: command = "bun run preview.ts"
            case .node: command = "node server.js"
            default: command = "node ./node_modules/.bin/vite --host 127.0.0.1"
            }
            return DevServer(
                pid: 88001 + index,
                processIdentity: ProcessIdentity(startTimeSeconds: 1, startTimeMicroseconds: 0),
                displayName: value.0, kind: value.1, ports: [value.2], hosts: ["127.0.0.1", "::1"],
                commandName: value.1 == .bun ? "bun" : "node", commandLine: command,
                workingDirectory: value.3
            )
        }
        store.lastRefresh = Date()
        store.statusMessage = "Found 6 local servers."
        switch scenario {
        case "empty": store.servers = []
        case "scanning":
            store.servers = []
            store.lastRefresh = nil
            store.isRefreshing = true
        case "error":
            store.servers = []
            store.errorMessage = "Process information could not be read. Try scanning again."
        case "port-only":
            store.servers = [.probedLocalhost(port: 8080)]
        case "long":
            store.servers[0] = DevServer(
                pid: 88001,
                processIdentity: ProcessIdentity(startTimeSeconds: 1, startTimeMicroseconds: 0),
                displayName: "customer-portal-search-preview",
                kind: .next, ports: [3000, 3001, 9229], hosts: ["127.0.0.1", "::1"],
                commandName: "/opt/homebrew/bin/node",
                commandLine: "node /Projects/customer-portal/worktrees/improve-search-accessibility/apps/web/node_modules/next/dist/bin/next dev --hostname 127.0.0.1 --port 3000",
                workingDirectory: "/Projects/customer-portal/worktrees/improve-search-accessibility/apps/web"
            )
        default: break
        }
        store.selectedID = store.servers.first?.id
        return store
    }
}

final class PreviewDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let dark = Bundle.main.infoDictionary?["PreviewAppearance"] as? String != "light"
        NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
