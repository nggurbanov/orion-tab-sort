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
