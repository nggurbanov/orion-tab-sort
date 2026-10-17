# Memory behavior

The old integration recursively scanned every browser view each second through AppleScriptObjC. It also retained a private QA polling hook. A live investigation found millions of arrays and continuing native allocation growth.

In an isolated 41-view fixture, 399 calls through an NSObject-derived AppleScriptObjC callback produced 3,588 leaked arrays. Ordinary direct AppleScript traversal did not reproduce that array leak. Removing only list concatenation did not resolve the callback behavior. This evidence identified a reproducible contributor, not the cause of every browser allocation or a historical peak.

R48 contains the runaway idle growth by making connection work bounded and on demand, removing the private QA poller, and giving capture restoration an independent one-shot timer. A live idle comparison changed from +118,767 arrays over 78 seconds before containment to +1 array over 73 seconds afterward. An independent idle thread sample contained no AppleScript activity.

These are short-term observations. Individual AppleScriptObjC operations can still retain memory, and page/graphics heaps have their own lifetimes. Already leaked allocations need not disappear immediately.

A compiled Objective-C maintenance experiment completed 100,000 standalone scans without a reported leak, but Orion rejected the local module because its Team ID differed from the application's signer. Browser signing protections were left intact. That uninstalled experiment is not included in the current source package.

Do not reintroduce a permanent AppleScriptObjC maintenance timer. Any replacement must pass both isolated lifetime checks and the actual signed-browser loading path before being described as a usable fix.

## R49 retained native context

R49 preserves R48's on-demand connection and one-shot watchdog behavior. Transaction completion releases the before/applied/partial snapshots and transaction metadata only after a verified, persisted resolution. A journal I/O failure or failed compensation keeps that evidence and the native context available for explicit recovery.

The captured context, identity maps, pinned objects and view references can still be retained after a resolved transaction. Their safe release and reacquisition across real reconnect/capture paths has not been proven using the signed Orion runtime, so this change does not guess at cleanup. Foundation fixtures establish state handling and bounded timers, not browser-object lifetime. Do not clear retained references to force a revision upgrade, or claim R49 eliminates all operation-time retention. A separate live lifetime/reconnect acceptance check is still required.

### Explicit abandonment of a divergent retained transaction

The R49 source now has a separate inspected, explicitly confirmed **Archive evidence and finish without Undo** path (see the command/reply contract in `architecture.md`). It can finish when the old scope cannot be snapshotted, without selecting, moving, restoring or guessing native objects. Before clearing retained state it preserves the exact journal and the retained before/applied/partial evidence, identity/bindings/history, earlier recovery archive reference and inspected live observation in a unique protected archive, verifies them, and writes/read-verifies an `acknowledged` journal with `resolutionKind: abandoned`. Failure retains evidence and captured references for retry.

Only successful explicit abandonment releases the old `contextItems`, pinned objects, selection token, persistent identity, per-capture UUID bindings, exposure candidates, identity views/histories and leftover capture arrays/UI-restoration references, together with transaction snapshots/metadata. A pending capture refuses abandonment, so its restoration data cannot be cleared by this path. Session-wide weak native-object identity mapping, scope UUID mapping, session key and sidebar/controller connection references remain intact. Earlier recovery archive files remain untouched. Keep, Undo and recovery retain their existing cleanup behavior.

The retained inspection itself is one frozen JSON-compatible evidence graph per transaction; a new successful inspection replaces it and transaction completion clears it. Protected archive files contain private browsing evidence and intentionally remain on disk. No archive cleanup policy is introduced.

Foundation fixtures verify release only after successful archive/finalization, preservation on each I/O/verification failure, and permission for a fresh explicit capture through the production capture guard. Private scope acquisition is synthetic. No signed Orion runtime, real object deallocation, reconnect behavior or memory usage was measured; this is a transaction exit, not a memory-performance result.
