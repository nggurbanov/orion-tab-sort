# Orion Tab Sort

Organize existing tabs in Orion's native vertical tree, with an AI-generated preview, explicit Apply, and Undo.

**Status:** private development repository. The current bridge is R48 and runs on demand. The native integration is deliberately restricted to **Orion 1.1.3 (152) on macOS**. It uses private browser APIs and must be reviewed for each supported build. The controller UI is currently in Russian.

## Features

- Read the current native tab tree, including sleeping tabs and duplicate URLs.
- Preview a proposed hierarchy before applying it to existing tab objects.
- Preserve pinned tabs, selection, navigation history, order and expansion state.
- Undo within the current browser process, or keep a finished sort and move to another group.
- Inspect a recovery journal after interruption.
- Use OpenRouter or a compatible API endpoint; store API keys in macOS Keychain.

The bridge has no permanent background view scan or automatic startup agent. Click **Native Tree Bridge** when the sorter is needed. Existing native tab organization remains available without a running bridge.

## Development

Requirements: Node.js 24+, Python 3, and macOS with Xcode Command Line Tools for the native checks and runtime compilation. There are no package dependencies to install.

```sh
npm test
npm run test:native       # macOS; isolated fixtures, no Orion automation
npm run package           # creates dist/orion-tab-sort-0.4.5.zip
```

The JavaScript suite also runs on Linux. GitHub Actions runs JavaScript checks and the isolated macOS bridge checks. Automated tests do not establish full browser compatibility; live validation is a separate step.

## Local setup

1. Package the extension with `npm run package`.
2. In Orion, use **Tools → Extensions → Install from Disk…** to install the generated ZIP.
3. Find its extension ID. Open the extension controller and copy the 32-character host from `chrome-extension://<extension-id>/sorter.html`.
4. Build a machine-local runtime, replacing the placeholder ID:

   ```sh
   python3 scripts/build_runtime.py \
     --extension-id YOUR_32_CHARACTER_EXTENSION_ID \
     --output "$HOME/Library/Application Support/OrionTabSort"
   ```

5. Create an Orion **Programmable Button** named **Native Tree Bridge**, configured for AppleScript and sidebar output. Paste the generated `launcher.applescript` source into it.
6. Open the target tab group and its native vertical sidebar. Click **Native Tree Bridge**, then **Прочитать дерево** (Read tree).

The build only generates and compiles files; it does not start Orion, install the extension, alter browser preferences, or register a startup service. `--orion-state` can select another profile's `browser_state.plist` when needed. Do not move a configured runtime without rebuilding it, because generated paths point to its chosen location.

If a different bridge revision or configuration is already loaded, finish any pending Undo/capture and restart Orion manually before switching. Reopening the same runtime retains its current host and Undo data. Never discard runtime state to force an upgrade through.

The source templates contain no user-specific paths or extension ID. Generated configuration, compiled scripts and recovery state stay outside Git.

## Data flow

Reading and previewing are separate from applying a tree change. When an AI proposal is requested, the selected provider receives the selected ordinary tabs' titles, URLs and hierarchy. Pinned tabs, native identifiers, navigation history and API credentials are excluded from the proposal metadata. API keys are read from Keychain into memory for requests; they are not saved in extension settings.

The local runtime's `state/` directory can contain private URLs and recovery information. Do not commit it or post it in an issue. Synthetic examples are sufficient for tests and most bug reports.

## Repository layout

| Path | Purpose |
| --- | --- |
| `extension/` | Current controller, provider integration and tree planning |
| `native/Bridge.applescript` | Current on-demand bridge source template |
| `native/templates/` | In-process loader and sidebar launcher templates |
| `scripts/` | Reproducible packaging, runtime generation and isolated checks |
| `tests/` | JavaScript tests using synthetic browser data |
| `docs/` | Architecture and known limitations |

Historical prototypes, native experiments rejected by Orion's signing policy, personal investigation logs, browser snapshots, backups and prebuilt binaries are intentionally not part of this repository.

## Limitations and release readiness

R48 stops continuous bridge-driven idle leakage by removing its recurring scan and private QA poller. Individual AppleScriptObjC operations can still retain smaller amounts of memory. Previously leaked allocations may remain until a normal browser restart. This is containment, not a claim that all Orion or WebKit memory issues are repaired.

Before a public release: select a license, verify a clean installation on another Mac, complete the live Apply/Undo and restart/recovery acceptance checks for the packaged source, and review supported browser versions. No open-source license has been selected yet.

See [architecture](docs/architecture.md), [memory behavior](docs/memory.md), and [contributing](CONTRIBUTING.md).
