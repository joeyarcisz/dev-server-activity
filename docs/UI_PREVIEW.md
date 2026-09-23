# Native UI review

Build development-only preview apps with synthetic project names, paths and process IDs:

```sh
bash script/build_ui_preview.sh /tmp/dsa-ui-previews
```

Open a generated app to inspect the actual production SwiftUI views. Each app has a separate bundle identifier. Close its window to quit. These are local development artifacts, not signed or notarized releases.

The preview replaces the app entry point, injects sample state and disables automatic scanning. Manual Refresh and Stop still use production actions. Do not confirm a stop or manually refresh while inspecting synthetic state.

## Visual and interaction checks

- Light and dark populated views: readable names, ports, paths and process details.
- Minimum window: search does not overlap the title bar; stop actions stay visible.
- Long data: the full project path and command wrap, all three ports appear, and details scroll above the action bar.
- Port-only listener: both stop actions are disabled and the reason is visible.
- Empty, scanning and error states: distinct messages; refresh disabled during a scan.
- Search: type `docs`; only docs remains selected and the detail shows port 4321. Append `zzzz`; no detail or stop actions remain. Clear the search; the full list returns.
- Keyboard: focus a server row and use Up and Down to change the selection.
- Confirmation: open Stop or Force Stop, confirm the named server matches the selected row, then cancel. Do not confirm the action against preview data.

The scanner, process identity checks and termination behavior remain covered by `swift test`. The preview is for visual and interaction checks, not evidence of live process termination.
