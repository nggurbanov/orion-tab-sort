# Sidebar validation

## Reproduce

Requirements: Node.js 24+, Python 3, and macOS with Xcode Command Line Tools for native checks. No package dependencies are required.

```sh
npm test
npm run package
npm run test:native       # macOS only; isolated synthetic fixtures
python3 scripts/build_runtime.py --extension-id aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa --output /tmp/orion-tab-sort-validation
npm run demo
```

Use a fresh output directory for runtime compilation. The builder compiles synthetic configuration without installing the bridge or opening Orion. Portable Python tests skip the runtime compilation case on other platforms.

The package test builds twice, compares SHA-256 and checks the exact 11-file allowlist. The extension ZIP contains only manifest, API, controller HTML/CSS/JS, planner, tree renderer, provider, settings, identity and recovery modules. Demo, screenshots, design references, private planning and local state are excluded.

## Automated coverage

- Actual controller, provider and planner code runs with synthetic transport/fetch boundaries: Auto applies once, Advanced requires Apply, unchanged/invalid proposals do not mutate, frozen credentials survive asynchronous work, cancellation ignores stale progress, and mode/scope locks preserve held state.
- Unknown mutation outcomes cannot unlock from a familiar phase or unrelated reply. Only the exact late request ID resolves the lock; no automatic replay occurs.
- Recovery tests bind confirmation to exact inspected journal identity/revision and live revision, reject stale/unavailable evidence appropriately, and invalidate confirmation after scope changes or failed resolution.
- Completed native-session journals normalize through the native handler before startup controls unlock. Unfinished journals remain blocked. Prior-session recovery without a focused group requires explicit selection before capture, inspection and acknowledgment.
- macOS transaction fixtures exercise shipped Foundation command handlers with synthetic snapshot/move/I/O boundaries. They cover write-ahead journals, Apply/Undo compensation, retained recovery, protected byte-verified abandonment, completed-session retirement and prior-session acknowledgment. They never load Orion.
- Tree-renderer tests cover safe text, local SVGs, depth-8 hierarchy/search, duplicate hints and moved rows. The synthetic demo uses the actual extension UI/controller scripts with a network-blocking CSP.

## Browser checks

Run the [demo](../demo/README.md) and inspect Auto and Advanced at 280, 360 and 480 px, plus a wider popup. Include light/dark themes, long titles/duplicate URLs, depth 8, empty/no-change results, generation/cancellation and recovery states. Check body/tree overflow, focus visibility and keyboard order, search with ancestor context, reduced motion, readable status and one contextual primary action.

Captured synthetic-UI checks covered Auto/Advanced at 360 px, long/dark and deep/light at 280 px, Auto generation at 480 px and Advanced at 1280 px. Synthetic cancellation emitted no mutation; Auto applied once, Undo returned idle, Keep returned accepted/idle, and Advanced emitted no Apply before its explicit action. The [README captures](../README.md#sidebar-preview) show actual synthetic UI with fictional data. These observations do not establish full keyboard, assistive-technology or reduced-motion acceptance.

## Limits

No real AI request, live Orion Apply/Undo, browser restart, bridge installation or installed-runtime change is part of these checks. Native compilation and synthetic fixtures do not establish signed-browser behavior, a clean installation on another Mac, restart/recovery correctness in a live session, or long-running reconnect behavior. Each supported Orion build still needs that acceptance. Local test results do not establish a completed CI run.
