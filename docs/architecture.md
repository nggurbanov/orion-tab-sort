# Architecture

## Controller and bridge

`extension/sorter.html` is the controller document. Its JavaScript reads the selected scope, obtains a proposed plan from the configured provider, validates the result, renders the preview, and sends explicit native commands. The current package has no diagnostic background page.

`native/Bridge.applescript` registers the versioned R49 NSObject-derived AppleScriptObjC delegate through Orion's in-process programmable-button executor. The generated loader retains it in a hidden native menu item, allowing the controller document to reload without discarding Undo state. A `WKScriptMessageHandler` connects the configured extension origin to that delegate. Main-frame origin, payload and command guards reject unrelated callers.

There is one runtime configuration per browser process. The loader refuses another bridge revision, extension ID or journal path instead of silently replacing its state.

## Native identity and mutation

The bridge reads Orion's native vertical-tree data source rather than assuming `openerTabId` describes the current tree. It retains actual tab objects for the captured scope; duplicate URLs are metadata, not identity. The pinned wrapper prefix is checked against the complete ordinary suffix, including duplicate counts, before it is accepted.

Plans must contain every ordinary captured tab exactly once, remain within the selected scope, and satisfy parent/cycle/depth constraints. Apply, Undo and recovery are guarded against stale native objects and changed page state. Journals record the transition boundary so an incomplete mutation is not silently treated as success.

## Lifetime

The bridge connects on demand. A panel-mount request may retry every 250 ms, at most 20 times. Once the panel is connected or the window expires, that timer is invalidated. There is no permanent view-scan timer, QA poller or startup agent.

A separate one-shot capture watchdog restores an expired identity capture even if the controller disappears. Each timer carries its capture token, and stale callbacks cannot clear a newer watchdog or cancel a different capture. Command handling rearms the watchdog before attempting to send the reply.

The generated heartbeat is a connection record, not proof of ongoing liveness. No recurring heartbeat writer is installed.

## Build boundaries

Extension packaging uses a fixed source directory and deterministic ZIP timestamps. Runtime generation substitutes only the chosen runtime root, extension ID and Orion profile state path, then compiles all scripts before updating generated runtime code. Existing runtime state is preserved.

Browser automation, snapshots, recovery files, API credentials and historical native prototypes are outside this repository. The build does not change the running installation.

## Transaction and recovery contract (R49)

Transaction phase is independent of snapshot presence. A version 2 journal has a unique `transactionID`, the original `before` snapshot, a `target`, native session identity, and any retained `applied`/`partial` evidence. Atomic journal writes must finish before the first Apply or Undo move. These writes and synthetic tests do not establish power-loss durability or live browser compatibility.

Apply writes `prepared`, performs and verifies the native layout, then writes `applied`. Undo is available only for that verified applied transaction, with matching live tree and journal. It writes `undoing`, restores and verifies the original layout, then writes `undone`. Keep checks the same live layout and journal transaction before creating a byte-verified 0600 archive and atomically recording `accepted`.

After a move or finalization error, Apply compensates to the original layout; Undo compensates to the verified applied layout. Failure to write `rollingBack` never prevents that restoration. Failed compensation sets `recoveryRequired`, retaining original objects, the last inspectable partial snapshot (or its verification error), and the journal. A restored layout whose final journal write failed is separately reported as `restoredJournalPending` or `appliedJournalPending`; it is not a completed transaction.

Replies include `transactionPhase`, durable `journalPhase`, `canUndo` and `needsRecovery`. Snapshot presence alone cannot enable Undo or Keep. Disk corruption, journal mismatch and a divergent applied tree disable Undo and indicate recovery. A new Apply accepts only explicitly resolved journal phases. Unknown phases fail closed.

### Controller integration for recovery

These native commands are implemented; controller UI wiring is separate work. No automatic retry or acknowledgment is scheduled.

- `transactionStatus`: returns the same state fields used in every bridge reply.
- `recoverRetained`: requires a fresh snapshot's `expectedRevision` and explicit `target: "original"` or `"applied"`. Available for retained failed/pending transactions in this process; the applied target requires a previously verified applied snapshot. It retries compensation and clears evidence only after verified restoration and a successful final journal write. If a fresh snapshot cannot prove object membership/page state, recovery stays blocked.
- `inspectJournal`: returns `journal` and `journalRevision` (the exact file bytes encoded as base64). The revision is an opaque comparison token, not a credential.
- `acknowledgeCurrent`: requires explicit controller user confirmation (`confirmed: true`), `expectedJournalRevision`, `expectedJournalVersion`, the exact `expectedJournalIdentity`, and a fresh live `expectedRevision`. It accepts only unfinished journals (`prepared`, `undoing`, `rollingBack`, `recoveryRequired`) with version 1 or 2 and a provably different native session key. It refuses retained same-process state or a pending capture. No old window/tab ID is mapped to the current tree. The original file is copied to a unique `.acknowledged-UUID` archive, protected to 0600 and byte-verified before the journal is atomically resolved as `acknowledged`. This records acceptance of the inspected current layout; it never claims restoration of the original tree. Failed archiving/finalization keeps the block and original evidence.

The existing `recover` command still requires verified UUID membership, scope, revision, URLs, active identity and exact planned parents/order/expansion; a changed native-session key is rejected before mutation. Its original journal is now protected and verified before a new write-ahead, and its failures use the same compensation machinery. The existing automatic retirement of a completed `applied` native-session journal after process change remains limited to completed sorts; unfinished journals are never silently retired.

### Isolated verification

`scripts/check-native-transactions.py` extracts the shipped `performCommand` and all transaction/recovery handlers without rewriting their decisions. Synthetic boundaries replace snapshot inspection, native layout/root moves and fault-injected I/O; production node validation, journal encoding, protected archive verification and resolution writes run against Foundation objects and temporary files. The suite covers both original regressions, every transaction journal boundary, compensation failure, retained recovery, Keep divergence, prior-session acknowledgment and exact installer guards. It does not load Orion or prove private native move behavior.

The two original regressions were reproduced against the baseline before source edits: a partial Undo was not compensated, and a failed `rollingBack` journal write skipped Apply restoration.

R49 changes the class, hidden host name, heartbeat, bundle path/metadata and generated runtime marker together. The loader refuses another loaded revision, extension ID or journal path without discarding state. The exact Orion 1.1.3 build 152 guard remains unchanged. No running runtime was upgraded during these checks.
