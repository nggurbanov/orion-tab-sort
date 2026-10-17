# Sidebar source verification — 2026-10-17

Prepared on isolated `feat/sidebar-modes`, starting at `adf15e8b17cba28193fecf3475af50e688f145ea`. No native implementation or native check scripts were changed. Parent-owned final native followup is integrated and verified separately; the controller contract was reviewed read-only against that final source.

## Observed portable checks

- Node 24: `npm test` — 131 JavaScript tests passed, no JS skips; Python reported 4 tests, OK with 1 macOS-only runtime compilation test skipped (3 executed).
- Controller coverage includes Auto exactly-one Apply, Advanced no auto-Apply, unchanged/failed AI, missing/denied settings, native identities/duplicates, stale group/tree, immutable credentials across deferred native/permission replies, cancellation/stale progress, retained Undo, mode/duplicate-click guards, bounded diagnostics and sanitized errors.
- Timeout coverage includes late success, unavailable reconciliation, partial mutation, timed-out Undo/Keep with pre-existing `applied` status, unrelated replies and late refusal. No phase-only unlock or automatic replay.
- Recovery coverage includes exact inspected values, `journal.applied` availability, unavailable live state with explicit null, previous-session acknowledgment, failed-resolution confirmation invalidation and subsequent proposal after resolved recovery.
- Actual tree renderer exercised with synthetic DOM boundaries: safe text, local SVGs, local collapse, ancestor-preserving depth-8 filter, duplicate distinctions and moved rows. All depth options 1–8 are represented in English markup.
- `npm run package` passed. Two independent builds produced the same SHA-256: `6153440dccb3a29c52a55976f8c683d08e2528c0958b037490bc6064bd84de6f`.
- ZIP contains exactly 11 allowlisted sources: manifest, api, sorter HTML/CSS/JS, planner, tree view, provider, settings, identity and recovery. Demo, design references, private settings and caches are excluded.
- Local Markdown references checked across 11 Markdown files: no missing targets. Full source credential/personal-path scan: no matches. All extension/demo JS parsed and git diff whitespace check passed.
- Synthetic demo HTTP serves the actual UI/controller scripts on loopback `127.0.0.1:4877`; its CSP blocks network connections and images. Scenarios, themes and long/deep fixtures are documented in [demo](../demo/README.md).

## Explicitly not established here

`npm run test:native` and compiled synthetic runtime were skipped on Linux: macOS osascript/osacompile, Foundation and AppKit are required. Parent owns those checks after integrating native work; their reported results are not claimed as this executor’s runs.

No browser automation was performed by this executor. Parent reported a first T3 preview batch at 360 px Outline, 280 px long/dark and deep, and 480 px Auto generation: Advanced did not Apply, cancellation made no mutations, depth options and duplicate ordinals were present, and no horizontal body/tree overflow was observed. That review found action placement/status visibility/view-state issues, corrected in this source batch. One parent confirmation capture remains outstanding, along with any broader keyboard/reduced-motion acceptance. These are parent-reported observations, not this executor’s independent browser runs.

The correction makes Auto compact with one action slot (Organize → proposal Cancel → disabled Applying → Undo); Advanced has one contextual primary, status above its viewport-fitted tree, and compact secondary controls. Current/Proposed reflects the actually available tree. Duplicate ordinals are precomputed once; full title/URL is exposed as tooltip/accessibility text. `chrome=0` hides only the demo controls. Changed/new HTML, CSS and JS were formatted; JavaScript formatting was checked for equal syntax trees using an existing remote parser/generator, with no added dependency. The actual demo scripts were also smoke-tested across 10 scenarios/fixture combinations through synthetic DOM boundaries; this is not browser rendering acceptance.

No real Orion state, tabs, installed runtime, credential or network AI was accessed. No app was restarted. A clean install on another Mac, signed-browser native mutation/Undo, restart/recovery behavior and lifetime/reconnect acceptance remain unverified.

Existing GitHub Actions defines Linux test/package and macOS native/compilation jobs. No workflow run was started for these unpushed commits. No push, merge, publication or repository visibility change occurred.
