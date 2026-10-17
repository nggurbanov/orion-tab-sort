# Architecture

## Controller and bridge

`extension/sorter.html` is the controller document. Its JavaScript reads the selected scope, obtains a proposed plan from the configured provider, validates the result, renders the preview, and sends explicit native commands. The current package has no diagnostic background page.

`native/Bridge.applescript` registers the versioned R48 NSObject-derived AppleScriptObjC delegate through Orion's in-process programmable-button executor. The generated loader retains it in a hidden native menu item, allowing the controller document to reload without discarding Undo state. A `WKScriptMessageHandler` connects the configured extension origin to that delegate. Main-frame origin, payload and command guards reject unrelated callers.

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
