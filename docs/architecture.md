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

### Explicitly finish a retained transaction without Undo

A verified Apply can later diverge when tabs are reorganized, selected, navigated or closed. `transactionPhase` may still be `applied` while `canUndo: false` and `needsRecovery: true`. Keep and Undo continue to refuse. The separate user action **Archive evidence and finish without Undo** deliberately abandons retained Undo/recovery; it does not keep a verified layout or restore anything. The controller must explain this before obtaining confirmation. It must never run this action automatically after an error or timeout.

The new commands extend the R49 source contract; the installed runtime was not changed. Dispatch uses the existing `{id, command, payload}` request and `{id, ok, result}` / `{id, ok: false, error}` reply envelopes. Every reply also carries `transactionPhase`, `journalPhase`, `canUndo`, and `needsRecovery` at the top level. Controller wiring belongs to plan 002 and the later UI work.

1. Send `inspectRetainedTransaction` with an empty payload. It requires a retained non-idle transaction with an original snapshot and transaction ID, no pending capture, and a readable journal dictionary with supported version 1 or 2 and an identity dictionary. It reads without writing files or moving tabs. It freezes the retained evidence and creates an opaque process-local `inspectionToken`; a newer successful inspection invalidates the old token. Its `result` is:

   ```js
   {
     inspectionToken, transactionID, transactionPhase,
     journal,             // parsed current journal; historical evidence, not live truth
     journalRevision,     // exact current bytes as base64; opaque comparison value
     journalVersion, journalIdentity,
     live: { available: true, revision, snapshot }
     // OR live: { available: false, revision: null, snapshotError }
   }
   ```

   A closed window/tab, navigation or changed active selection can make the old snapshot unavailable. Inspection still works: `snapshotError` describes the observation failure. Neither its absence nor repeated failure proves any current layout or identity. No replacement tab/window is inferred.

2. After explicit user confirmation, send `abandonRetainedTransaction` with these required fields copied from that inspection:

   ```js
   {
     confirmed: true,                         // JSON boolean, not 1 or "true"
     inspectionToken: inspection.inspectionToken,
     expectedTransactionID: inspection.transactionID,
     expectedJournalRevision: inspection.journalRevision,
     expectedJournalVersion: inspection.journalVersion,
     expectedJournalIdentity: inspection.journalIdentity,
     expectedLiveAvailable: inspection.live.available, // JSON boolean
     expectedRevision: inspection.live.revision        // explicit null if unavailable
   }
   ```

   Native validation binds the token to all retained before/applied/partial evidence, phase, transaction ID, session, retained identity/bindings/history and recovery archive reference, as well as the exact journal bytes/version/identity. If live state was available, its complete snapshot and revision must still match; changing availability in either direction requires reinspection. If it was unavailable and remains unavailable, no layout comparison is claimed (error text may differ). Missing/wrong fields, stale tokens, concurrent captures and journal/transaction changes refuse without moves or clearing retained state. An already mismatching journal transaction ID may be explicitly inspected and archived together with the retained transaction; this never enables Keep/Undo or identity mapping.

3. Native code creates a unique journal-adjacent `.abandoned-UUID/` directory, protected to 0700 from creation, containing 0600 `original-journal.json` (byte-exact original file) and `retained-evidence.json`. The latter records `resolutionKind: "abandoned"`, the full frozen inspection (including the available live snapshot or unavailable observation), and retained before/applied/partial snapshots, identity, bindings, history and any earlier recovery archive path. Absent retained values are explicit JSON nulls. Existing recovery archives remain untouched. Encoding is checked for evidence equality; file bytes and permissions are read back before finalization and again before releasing references. Changes during archive I/O are revalidated before writing the journal.

4. Only after verified archiving, native code atomically writes and reads back a journal with `phase: "acknowledged"`, `resolutionKind: "abandoned"`, an explicit statement that restoration/current layout are not verified, `abandonedTransactionID`, `archive`, and `evidenceArchive`. Historical journal fields remain evidence. The successful command's `result` is:

   ```js
   {
     acknowledged: true, abandoned: true,
     restorationVerified: false, currentLayoutVerified: false,
     transactionID,
     archives: { archive, evidenceArchive },
     journal // finalized historical journal; not a fresh current snapshot
   }
   // Envelope state: transactionPhase: "idle", journalPhase: "acknowledged",
   //                 canUndo: false, needsRecovery: false
   ```

   Success consumes the token and releases that transaction's snapshots and captured native context. Session-wide identity maps, session key, sidebar and controller connections remain. A new explicit capture is permitted and required before further use; the reply is not a new preview.

Any archive, protection, byte-verification or finalization failure keeps retained evidence and native references, blocks capture, and returns `ok: false`. Partial archives are preserved, never deleted or overwritten; each retry uses a new unique directory. The same token can retry if the journal/transaction/live observation still match. If finalization actually wrote before a verification/reply error, the old token is stale: inspect again, present the newly observed state, obtain fresh confirmation, and archive that version too. Do not replay after an unknown timeout; reconcile the top-level state with read-only `transactionStatus`/inspection first. A missing, malformed or unsupported journal refuses inspection and is never silently discarded. These filesystem checks do not establish fsync/power-loss durability.

The existing `recover` command still requires verified UUID membership, scope, revision, URLs, active identity and exact planned parents/order/expansion; a changed native-session key is rejected before mutation. Its original journal is now protected and verified before a new write-ahead, and its failures use the same compensation machinery. The existing automatic retirement of a completed `applied` native-session journal after process change remains limited to completed sorts; unfinished journals are never silently retired.

### Isolated verification

`scripts/check-native-transactions.py` extracts the shipped `performCommand` and all transaction/recovery handlers without rewriting their decisions. Synthetic boundaries replace snapshot inspection, native layout/root moves, supported-host/private scope acquisition and individual fault-injected filesystem calls; production node validation, journal/evidence encoding, archive decisions, protected byte verification and resolution writes run against Foundation objects and temporary files. The suite covers both original regressions, every transaction journal boundary, compensation failure, retained recovery, Keep divergence, explicit abandonment with unavailable snapshots, stale confirmation bindings, every abandonment filesystem failure/retry, fresh capture guards, prior-session acknowledgment and exact installer guards. It does not load Orion or prove private native move, capture or lifetime behavior.

The two original regressions were reproduced against the baseline before source edits: a partial Undo was not compensated, and a failed `rollingBack` journal write skipped Apply restoration.

R49 changes the class, hidden host name, heartbeat, bundle path/metadata and generated runtime marker together. The loader refuses another loaded revision, extension ID or journal path without discarding state. The exact Orion 1.1.3 build 152 guard remains unchanged. No running runtime was upgraded during these checks.
