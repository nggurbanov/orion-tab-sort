# Synthetic controller demo

Run `npm run demo` on the development machine. The server binds only `127.0.0.1:4877`. Forward that port when reviewing remotely; open `/demo/` in the parent’s T3 preview.

The server serves actual `extension/sorter.html`, CSS, controller, planner, provider-settings and tree-view scripts. Only browser/native transport and AI proposal boundaries are synthetic. Demo CSP uses `connect-src 'none'`, `img-src 'none'`; no live Orion, external favicon, API key or network AI is used. The demo files are outside the extension ZIP allowlist.

Selectors and URL parameters:

- `scenario=idle|generating|preview|applied|nochanges|disconnected|recovery`
- `fixture=outline|long|deep` (depth 8; exact duplicates and long titles)
- `theme=light|dark`
- `mode=auto|advanced` (`preview` starts in Advanced)

Example: `/demo/?scenario=preview&fixture=long&theme=dark&mode=advanced`.

`window.OrionSorter.getState()` exposes bounded controller state, `window.OrionDemo.getState()` the synthetic native state, and `window.OrionDemo.requests` the last 40 command names only. `window.OrionSorter.run(action)` is the actual controller action path. This demo proves no native compatibility; record real browser layout/keyboard checks separately.
