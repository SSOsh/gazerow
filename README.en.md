# gazerow

A macOS utility for clicking on-screen buttons, links, and menus using only your
keyboard. Trigger the overlay with a shortcut and every clickable element gets a
letter label — type the label to focus an element, then confirm with a key to
click it without touching the mouse. (Homerow style)

*Read this in [Korean](README.md).*

- A tool for keyboard-centric users who want to operate apps without reaching for the mouse.
- Works by reading the macOS Accessibility tree; all data stays local.
- It is not an accessibility/assistive-technology product, and is not intended for medical or safety-critical use.

> **Work in progress.** Free beta ZIPs are not signed with Apple Developer ID or
> notarized by Apple. Only use the security override below when you trust the source.

---

## Free Beta Installation

The free beta contains a Universal `gazerow.app` that runs on both Apple Silicon
and Intel Macs. It does not require Xcode or Terminal.

1. Download `gazerow-*-macos-universal.zip` from
   [GitHub Releases](https://github.com/SSOsh/gazerow/releases), then unzip it.
2. Move `gazerow.app` to **Applications**.
3. Double-click the app once. macOS blocks it with an unidentified developer warning.
4. Open **System Settings → Privacy & Security → Security**, then choose
   **Open Anyway** for gazerow.
5. Launch gazerow again and follow the app guidance to grant **Accessibility permission**.

> The warning is expected because this free beta is not notarized by Apple.
> You can verify the ZIP with the accompanying `.sha256` file. A new beta may
> require Accessibility permission again because its ad-hoc signature changes.

```bash
# Optional: put the ZIP and .sha256 file in the same directory, then verify it
shasum -a 256 -c gazerow-0.1.0-beta.1-macos-universal.zip.sha256
```

---

## Quick Start

1. **Launch the app** — it appears as a gazerow keyboard-grid icon in the menu bar, with no Dock icon.
2. **Grant permission** — in the first-run guide (or Settings), allow **Accessibility
   permission** and press **Recheck**. Overlay and clicks require this permission.
3. **Open the overlay** — bring the app you want to operate to the front and press `Command+Shift+Space`.
4. **Type a label** — type the letter label shown over the element you want to click.
5. **Confirm the click** — press `Return` to click the focused element.

> No camera or eye tracking required. Gaze is an experimental feature and is off by default.

---

## How to Use

### Activating the overlay

| Action | Shortcut |
| --- | --- |
| Show overlay (primary) | `Command+Shift+Space` |
| Show overlay (secondary) | `Control+Option+Command+Space` |
| Show from menu bar | Menu bar icon → **Show Overlay** |

### Inside the overlay

Once the overlay is open, every actionable element gets a letter label (A, B, … AA, AB …).

| What you want | Key |
| --- | --- |
| Focus an element | Type its label letters (e.g. `F`, `AB`) |
| Click the focused element | `Return` |
| Search elements / switch windows | `/` / `;` |
| Move to next / previous candidate | `Tab` / `Shift+Tab` |
| Move up / down candidate | `↑` / `↓` |
| Clear the letters you typed | `Delete` |
| Close without clicking | `Esc` |

Keyboard layout is handled automatically. No conversion setting or layout switch is required.

### Query Overlay

After opening the overlay, press `/` to pin element search or `;` to pin window search.
You can also click the `Windows` / `Elements` / `Labels` chips in the bottom status bar to switch scopes.
Type a query to show the match count and focused target in the status area.
Use `Tab` / `Shift+Tab` to cycle query matches, and `Delete` to edit the query.
In element scope, `Return` clicks the focused element; in window scope, `Return` switches to the selected app/window.
When there is no match, the previous label focus is cleared so `Return` does not trigger an old label.
Bare letter input still prioritizes label selection, so the existing label flow remains intact.

### Window control shortcuts

Press the frontmost window's standard title-bar buttons (close / minimize / zoom)
from the keyboard. These work only while gazerow has Accessibility permission.

| Action | Shortcut |
| --- | --- |
| Close window | `Control+Option+C` |
| Minimize window | `Control+Option+M` |
| Zoom window | `Control+Option+Z` |

### Kill switch

**Disable** the session from the menu bar icon or Settings to stop overlay
activation immediately. **Enable** it again to resume.

---

## Click Safety

- **No auto-click.** Every click requires explicit confirmation with `Return`.
- Risky actions (destructive, external effects, unknown risk) require **a second confirmation**.
- Clicks use accessibility actions (`AXPress`, `AXConfirm`, `AXOpen`, `AXShowDefaultUI`).
- To reduce mis-clicks, **coordinate-based click fallback is off by default**.
- Secure fields (e.g. passwords) are excluded from candidates during scanning.

---

## Privacy

- All processing happens **locally**; nothing is sent over the network.
- Interaction log storage is **off by default (opt-in)**. Even when enabled, only
  minimal focus/click events are stored, and window titles are stored **only as a
  per-session hash** — raw titles and text values are never saved.
- The baseline **does not request camera or input-monitoring permissions**.
- Debug Export saves a plain-text diagnostics snapshot for troubleshooting; it does
  not include raw window titles or text values.

---

## App Support

| App | Support tier |
| --- | --- |
| Finder | Supported |
| Safari | Supported |
| Chrome | Supported |
| VS Code | Supported |
| System Settings | Supported |
| Slack | Supported |
| Notion | Supported |
| Discord | Limited (candidates appear, but representative click not yet verified) |
| Obsidian | Unverified (not installed in the evaluation environment) |

**Tier meaning**

- **Supported**: passed real click-task verification.
- **Limited**: works, but with constraints on candidate collection or clicking.
- **Unverified**: not yet verified.

---

## Known Limitations

- Only the frontmost app's focused window is scanned.
- Some apps expose an incomplete accessibility tree, so some candidates may be missing.
- Elements without a supported accessibility action may not be clickable.
- Coordinate-based click fallback is off by default and is used only on explicitly
  confirmed overlay click paths.

---

## Requirements / Install

| Item | Value |
| --- | --- |
| Minimum macOS | macOS 14 |
| App type | Menu bar app + Settings window |
| Required permission | Accessibility |
| Languages | Korean / English |

The beta ZIP does not require Xcode. Building from source uses Swift Package
Manager and **requires Xcode 15 or newer (Swift 5.9 or newer)**. Xcode 14 and
older are not supported because the app uses macOS 14 and SwiftUI Observation APIs.

```bash
# Accept the Xcode license once (if needed)
sudo xcodebuild -license accept

# Build / run (with the Xcode toolchain)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run

# Open the Accessibility permission request/settings flow and run
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run gazerow -- --request-accessibility

# Build a local .app bundle and run it as a single instance
scripts/run_local_app.sh

# Gracefully stop an existing gazerow before replacing it with the new build
scripts/run_local_app.sh --replace-running

# Build the free Universal beta ZIP and SHA-256 checksum
scripts/package_beta_release.sh
```

> **Note**: if multiple Xcode versions are installed, specify the intended toolchain
> with `DEVELOPER_DIR` as above. The local `.app` bundling/signing flow is verified
> with the full Xcode app installed. Do not use `open -n`, because it intentionally
> starts another app instance.

After launching, click the keyboard-grid icon in the menu bar to try **Open Settings** /
**Quit** and confirm it works. Without permission, use the **Request Permission**
button in Settings or the launch option above to open the permission flow.

---

## Support

If gazerow helps your workflow, support development via **Support gazerow** in the
menu bar. Choose **Copy Account Number** to copy the KakaoBank account
`3333-26-7184989` to the clipboard.

---

## Developer Docs

For implementation details — build/test, project structure, ticket history — see the
`plans/` folder.

```bash
# Run tests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
