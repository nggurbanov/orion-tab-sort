# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Orion users with many hierarchical, sleeping and duplicate tabs who need practical organization without rebuilding their browsing sessions.

## Product Purpose

A compact English utility for organizing existing tabs in Orion’s native vertical sidebar. Auto is the default: one **Organize tabs** click authorizes reading the visible selected group, an AI proposal and guarded Apply. Advanced exposes a guided **Read / Review / Apply** flow with the approved Outline hierarchy. Both use the same guarded controller path.

## Positioning

Preserve native tab objects, pinned tabs, selection, navigation history, sibling order and expansion guarantees. Make connection, target group, progress, Undo and unresolved recovery understandable. No marketing surface, manual tree editing, unsupported row menus, favicon requests or startup service.

## Operating Context

The native integration runs on demand on macOS, restricted to Orion 1.1.3 build 152. Private APIs need separate review for each supported build. The controller requires the R49 transaction schema; optional retained-inspection commands fail closed when an older R49 runtime lacks them. Source availability under MIT does not imply stable general compatibility.

## Capabilities and Constraints

- Auto keeps the hierarchy and guided controls hidden, with one action slot near the group/progress and no forced empty viewport; show honest phase/batch progress, never an invented overall percentage or time estimate.
- Advanced uses one contextual Read/Review/Apply primary with status above a viewport-fitted tree and compact secondary controls. It shows current/proposed title/domain rows, changed-row markers, duplicate occurrence hints, local collapse and keyboard search retaining ancestor context. Preview interaction never edits Orion.
- A visible selected group is frozen for each operation. Auto starts with the focused native group; unresolved Undo/recovery prevents scope switching.
- No-change results never Apply. After verified Apply, offer Undo and quiet Keep this order. Mode changes cannot discard transaction evidence or bypass operation locks.
- Cancellation applies to proposal work only. Native Apply, Undo and recovery cannot be cancelled midway.
- A mutation timeout means unknown outcome: bounded read-only reconciliation, no replay, and no unlock from an unrelated phase/status. Await the exact late request reply; allow read-only inspection.
- Credentials are captured with validated settings before asynchronous work, disabled while busy and saved only through origin-specific macOS Keychain. No credential persistence in checkpoints or diagnostics.
- Pinned tabs are excluded from AI metadata. Ordinary titles, URLs and parent relationships go to the selected provider only after explicit organization.
- Depth 1–8, light/dark system colors, narrow 280/360/480 px sidebars and wider popup layout are intended surfaces. Browser rendering and real native acceptance remain separate checks.

## Evidence on Hand

The automated suite exercises actual controller/provider/planner code with synthetic transport/fetch boundaries. The isolated browser demo uses actual extension UI scripts and blocks network connections. Native AppleScript compilation and signed-browser behavior require macOS. See [controller](docs/controller.md), [design](DESIGN.md) and [verification](docs/sidebar-verification.md).
