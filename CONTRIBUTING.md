# Contributing

This repository contains the current implementation, not the historical prototype workspace. Keep machine-local configuration, user browsing data, runtime journals and compiled artifacts out of commits.

## Checks

```sh
npm test
npm run test:native       # macOS only
npm run package
```

Use synthetic domains and tab records in tests. The native checks extract and exercise the shipped guards and timer handlers with isolated Foundation/AppKit objects. They must not launch Orion or operate on real tabs.

For an actual browser check, use a separate synthetic fixture and record the exact Orion build. Compare native membership, parent links, sibling order, pins, selection, history and expansion before and after Apply/Undo. An accepted API call, a tab count or a passing mock is not proof of native tree behavior. Revalidate private APIs before widening the browser build guard.

Preserve active Undo/capture state. Runtime generation must never replace `state/`, silently migrate another loaded bridge, start a background helper, or modify Orion's signing protections.

## Source versus generated files

Edit `native/Bridge.applescript` and the templates under `native/templates/`. Run `scripts/build_runtime.py` to generate a local runtime; do not hand-edit and commit its compiled bundle. Keep only the current supported bridge in the source tree. Summarize relevant design decisions in `docs/` instead of adding copied investigation transcripts.

Source is licensed under MIT, copyright 2026 nggurbanov. Keep experimental browser compatibility distinct from public source availability. A clean installation on another Mac, live Apply/Undo, restart/recovery and signed-browser lifetime checks remain separate acceptance work. Do not weaken signing or private build guards to make fixtures pass.

The controller defaults to Auto and shares proposal safety with guided Advanced. Preserve this distinction in changes and tests. Cover actual orchestration with synthetic native/fetch boundaries, especially immutable endpoint/key pairs, cancellation, stale groups and unknown mutation outcomes. A timeout is never permission to retry or to unlock from a familiar transaction phase.

Use `npm run demo` for browser review of the actual controller/tree view without Orion or network AI. Keep demo fixtures outside the extension allowlist; do not add dependencies for this purpose. Record exactly which 280/360/480 px, wide, theme, keyboard and reduced-motion checks occurred in [verification](docs/sidebar-verification.md). The design contract is [DESIGN.md](DESIGN.md).
