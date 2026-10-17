# Orion Tab Sort

Organize existing tabs in Orion’s native vertical tree with **Auto** or guided **Advanced** mode, guarded Apply and Undo.

**Experimental macOS integration, MIT licensed.** The R49 bridge is restricted to **Orion 1.1.3 (152)** and uses private APIs. Each additional browser build needs separate review. Automated fixtures and source availability do not establish compatibility on another Mac, a clean installation, or restart/recovery behavior.

## Use

Open the target group and Orion’s vertical tab sidebar, then open **Native Tree Bridge**. The visible group selector identifies what will be organized.

- **Auto**, the default: one **Organize tabs** click authorizes reading the selected group, asking AI for an order and guarded Apply. Honest phase/batch progress replaces a manual preview step. No-change results never Apply.
- **Advanced**: **Read tree → Review with AI → Apply changes**. Search titles/domains and compare current/proposed hierarchy before applying. Preview collapse/search does not change Orion.
- After verified Apply, use **Undo** to restore the original tree or **Keep this order** to finish the transaction. Finish it before switching groups. Cancellation is available only during proposal work, never native mutation.

The native guards preserve tab objects, pinned tabs, selection, navigation history, sibling order and expansion. Sleeping tabs and duplicate URLs are included. These guarantees still require live acceptance against the supported signed browser; a passing synthetic fixture is not that proof.

The bridge runs on demand, without a permanent background view scan or automatic startup agent.

## Development

Requirements: Node.js 24+, Python 3; macOS with Xcode Command Line Tools for native fixtures/runtime compilation. No package dependencies.

```sh
npm test
npm run test:native       # macOS isolated fixtures; does not launch Orion
npm run package           # dist/orion-tab-sort-0.5.0.zip
npm run demo              # loopback synthetic UI: http://127.0.0.1:4877/demo/
```

JavaScript and portable Python tests run on Linux. GitHub Actions defines Linux tests/package and macOS isolated native/compilation jobs. A local pass is not a completed GitHub Actions run. The [demo](demo/README.md) uses actual UI/controller scripts with synthetic transport/AI, isolated from the extension package and blocked from network connections.

## Installation

1. Build the ZIP using `npm run package`.
2. In Orion choose **Tools → Extensions → Install from Disk…** and select it.
3. Open the extension controller. Its `chrome-extension://<extension-id>/sorter.html` host is the required 32-character extension ID.
4. Generate a runtime with that ID on macOS:

   ```sh
   python3 scripts/build_runtime.py \
     --extension-id YOUR_32_CHARACTER_EXTENSION_ID \
     --output "$HOME/Library/Application Support/OrionTabSort"
   ```

5. Create an Orion **Programmable Button** named **Native Tree Bridge**, configured for AppleScript and sidebar output. Paste its generated `launcher.applescript` into the button.
6. Open the desired group and vertical sidebar, click **Native Tree Bridge**, and configure AI endpoint/model/key in **AI settings**. Credentials save through macOS Keychain. Confirm the target group, then organize.

Runtime generation compiles files; it does not start Orion, install the extension, alter preferences, register startup services or modify signing protections. `--orion-state` selects a different profile when needed. Generated paths are specific to the runtime location; rebuild before moving it. The controller requires R49 reply state; retained evidence inspection additionally requires the final R49 inspection/abandonment handlers.

## Recovery and upgrades

If an operation times out, its outcome is **unknown**. Do not repeat Apply/Undo/Keep. Mutations stay locked; reconnect and read-only inspection can reveal state but cannot correlate completion of the timed-out request. Only its exact late reply resolves that controller lock. Keep the evidence and report the unresolved operation if that reply never arrives.

**Recovery** offers guarded original-tree restoration, retained transaction inspection and previous-journal inspection. Acknowledge current layout and abandon Undo/recovery require an inspection and explicit consequence confirmation. They archive evidence and never claim original restoration. Abandonment moves no tabs and permanently ends that retained Undo/recovery; it can explicitly preserve an unavailable live observation. Unsupported or stale inspections refuse resolution. See [controller recovery](docs/controller.md).

Before upgrading, finish or inspect any retained Undo/capture/recovery, preserve the runtime’s `state/` directory and its journal-adjacent archives, and rebuild from the reviewed source. Another already-loaded bridge revision/configuration is refused. A normal manual Orion restart may be needed to switch revisions; never discard state to force replacement. Completed order is intended to persist across restart; same-process Undo does not. Restart/upgrade acceptance on another Mac remains unverified.

## Privacy

The selected provider receives ordinary tabs’ titles, URLs and parent relationships only after organization is requested. Pinned tabs, navigation history and native identity tokens are excluded. Tab data is untrusted input; returned plans are validated locally. Credentials go only to the frozen endpoint; requests omit cookies, reject redirects and do not cache. HTTP is permitted only for localhost/127.0.0.1; IPv6 loopback is unsupported.

Keys load from origin-specific macOS Keychain into memory. They are excluded from extension settings, checkpoints and diagnostics. Local extension checkpoints and native runtime recovery journals can contain private URLs/snapshots. Never commit or upload them. Event diagnostics keep at most 24 action names; provider diagnostics at most 8 bounded metadata records. The UI uses local document SVGs and makes no favicon requests.

## Support and uninstall

Report bugs in the repository’s Issues with the exact Orion/macOS build, controller version, operation and sanitized status. Prefer the synthetic demo; do not post real keys, browsing snapshots or recovery journals. Support is experimental for the guarded browser build, with no broad compatibility promise.

To uninstall, resolve or explicitly inspect retained state first. Remove the extension and programmable button using Orion’s own controls. Keep a private copy of the configured runtime and recovery archives before choosing whether to remove them. Runtime generation installs no startup agent. If deleting a saved API key, remove only its matching `local.orion-tab-sort.ai.v1` Keychain service entry for that provider origin account using Keychain Access; do not erase unrelated credentials.

## Source

[MIT license](LICENSE), copyright 2026 nggurbanov. `package.json` stays private to prevent accidental npm publication; that does not restrict the MIT source license. Public repository visibility is a separate owner action after review.

See [contributing](CONTRIBUTING.md), [architecture](docs/architecture.md), [controller](docs/controller.md), [design](DESIGN.md), [verification](docs/sidebar-verification.md), [memory behavior](docs/memory.md) and [changelog](CHANGELOG.md). Machine-local configuration, binaries, personal snapshots and historical prototype workspaces are excluded.
