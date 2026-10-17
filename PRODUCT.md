# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Orion users with many hierarchical, sleeping and duplicate tabs who need practical organization without rebuilding their browsing sessions.

## Product Purpose

Organize existing tabs in Orion’s native vertical tree through an AI-generated preview, explicit Apply, and Undo or Keep. The controller should be a compact English sidebar with a readable hierarchy and obvious transaction states and actions.

## Positioning

The sorter operates on existing native tab objects. Preserving pinned tabs, selection, navigation history, order and expansion state is a core requirement.

## Operating Context

The browser integration runs on demand on macOS and is restricted to Orion 1.1.3 build 152. It uses private APIs that require review for each supported browser build. There is no idle polling. Reading, requesting an AI preview and applying changes are separate actions.

## Capabilities and Constraints

- Read native tab trees, including sleeping tabs and duplicate URLs.
- Preview a hierarchy before Apply; offer Undo or Keep after a verified change.
- Preserve native browsing state and retain recovery evidence after interruption.
- Public release under MIT is intended after verification; release readiness and broader compatibility are not established.
- The existing controller is in Russian. An English sidebar is the confirmed direction, not a shipped claim.

## Evidence on Hand

README.md describes current behavior and limitations. Native source, isolated fixtures and packaging checks are in this repository. Full live acceptance remains separate from synthetic tests.

## Product Principles

- Keep large tab hierarchies readable in a compact sidebar.
- Make preview, Apply, Undo and Keep clear and explicit.
- Preserve native objects and browsing state; fail safely when identity or recovery cannot be verified.
- Make compatibility claims only for verified builds and behavior.
