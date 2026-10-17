# Controller behavior and recovery

The sidebar defaults to **Auto**. Its Organize tabs button authorizes capture → AI proposal → stale-tree/identity preflight → Apply within the selected group. No-change returns without Apply. **Advanced** shares that path through proposal, then requires Apply changes. Switching modes while idle preserves the preview and native transaction; switching during an operation is blocked. Auto always recaptures before a new proposal.

The controller requires `ping.host === "AppleScriptObjC native tree V3R49"` and complete `canUndo`, `needsRecovery`, `transactionPhase`, `journalPhase` state. Unsupported/malformed replies block mutation and provide update/reconnect help. The supported Orion build is enforced natively. The scope selector starts from the focused group, stays visible and freezes while busy or retaining Undo/recovery.

Settings and the credential form one immutable pair before any asynchronous step. All editable provider settings lock during work. Endpoint changes clear the displayed key and load only that origin’s Keychain entry. Provider permission requests use the precise endpoint host pattern. HTTPS and HTTP localhost/127.0.0.1 match manifest/CSP; IPv6 loopback is deliberately rejected. Fetch omits cookies, rejects redirects and uses no cache.

An external AbortSignal propagates through provider stages, format retries, batches and fetch. Cancel generation never sends native cancellation for Apply/Undo/recovery; it stops additional AI requests and ignores stale progress/results. No overall percentage or estimated duration is invented.

## Native timeout

Any mutation timeout means **unknown outcome**. All further mutations lock. A bounded read-only reconciliation attempts ping, transactionStatus, inspectJournal and snapshot; it never retries the original command. R49 has no last-mutation receipt: even `applied`/`idle` may predate timed-out Undo/Keep. Status, a familiar layout or an inspection cannot unlock that request. Only its exact late request-ID reply with valid state resolves this controller’s unknown flag. A late `ok:false` is shown as failure/refusal. Without that reply, leave the lock and evidence intact; reconnect/update assistance must not claim that retry is safe.

## Recovery choices

Top-level native state is authoritative on success and failure. Retained same-process recovery is inspected with `inspectRetainedTransaction`. The user sees phase/live readability and the consequence; opaque IDs and large JSON stay internal. Restore original/applied uses the inspected live revision and requires readable live state. The applied target is offered only when the returned `journal.applied` exists. Failed resolution retains the block and requires a fresh inspection/confirmation.

**Abandon Undo / recovery** explicitly archives retained evidence and ends restoration rights without moving tabs. The request copies the inspectionToken, transaction ID, journal byte revision, version, identity, live availability and revision exactly; an unavailable live observation passes JSON null. Success must report acknowledged/abandoned, both layout-verification flags false, and resolved native state. It never claims the current or original layout was verified. A bridge without inspection support cannot enable it.

Previous-session unfinished journals use explicit current-group capture and `inspectJournal`, then `acknowledgeCurrent` with actual journal bytes/version/identity and a live revision. Native code proves the session differs. Acknowledgment means current-layout acceptance, not original restoration. Completed applied journals use the existing verified-current-tree acceptance route; UUID-matched recovery remains guarded by the native contract. See [native architecture](architecture.md).

## Privacy and retention

The event diagnostic ring holds at most 24 action names; it never retains trees, URLs, errors or credentials. Provider diagnostics hold at most 8 bounded records. Secrets are excluded from settings/checkpoints/errors. Local checkpoints can hold tab snapshots/URLs to preserve the guarded legacy identity route; native recovery journals also contain private browsing evidence. Treat these as private state, never attach them to issues.

Tree search/collapse is local presentation only. Safe textContent rendering, local SVG document icons and no favicon requests prevent tab content from adding markup/network resources.
