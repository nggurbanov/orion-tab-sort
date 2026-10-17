# Sidebar design

The selected reference is **A · Outline**. Its flat offwhite/ink/green material, fine separators, compact hierarchy and system typography are the visual contract. The user’s approved refinement adds two modes: Auto hides the tree by default; Advanced adds the Read / Review / Apply strip. Unsupported mock ellipsis menus and external favicons are omitted.

| Token | Light | Dark |
| --- | --- | --- |
| Background | `#f7f7f5` | `#232622` |
| Ink | `#202522` | `#f1f2ef` |
| Secondary text | `#626961` | `#b1b8ae` |
| Separator | `#d8dcd5` | `#474d44` |
| Field | `#ffffff` | `#2c302b` |
| Action / focus | `#315c48` | `#afcfbb` |
| Action ink | `#ffffff` | `#17281d` |
| Hover | `#e8ede7` | `#373e35` |
| Recovery text | `#85372d` | `#f0b3a6` |

Typography: `-apple-system, BlinkMacSystemFont, sans-serif`; body/title rows and standalone fields 13 px, default buttons/labels/search 12 px, mode/recovery buttons and domain/secondary hints 11 px, moved/duplicate hints 10 px (moved hints 9 px at widths up to 300 px), compact heading 15 px/650. No external fonts. Default control corners 5 px; tree toggles use 3 px and joined view controls square their shared corners. Default buttons use 7 × 9 px padding, fields 7 × 8 px, refresh 6 px, mode controls 4 × 5 px and tree toggles 3 × 0 px; quiet controls remove left padding. The recurring layout-spacing subset is 4/6/8/10/12/14/18 px, with smaller component-specific offsets. Fine 1 px separators; no decorative shadows, cards, gradients or art.

Auto: compact heading/mode choice, explicit group selector, honest status/progress and one primary action slot beside them; quiet secondary settings/recovery follow without a forced blank viewport. The slot changes Organize → Cancel generation → disabled Applying → Undo. Verified success replaces it with Undo and quiet Keep this order. No manual confirmation between AI and guarded Apply; the initial click grants that scope.

Advanced: same scope/controller with status/progress above the tree and one contextual primary (Read, Review, Apply, then Undo); other actions are secondary. The tree and compact secondary controls fit the viewport without a covering sticky footer. Guided steps, title/domain search, Current/Proposed views, locally expandable rows and moved indicators. The tree owns the viewport. Every preview uses textContent and generic inline document SVGs. Duplicate titles reveal address paths; exact duplicates have occurrence hints. Search retains ancestors and `/` focuses it when not editing a field. Collapse buttons and native HTML controls work by keyboard.

Both: 280/360/480 px and wider layout, system light/dark, 2 px green focus outline, themed selection/caret/scrollbar, no required animation and reduced-motion support. Unknown phases are indeterminate; only actual batch counts appear. Settings and mode controls lock during work. Recovery inspection presents phase/live availability and consequences without native IDs or raw JSON. Mutation confirmation is tied to the actual inspected evidence.

Reproducible visual/keyboard checks and their limits are recorded in [verification](docs/sidebar-verification.md). The deterministic demo supports every major phase and long/deep fixtures; passing Node tests alone does not establish those visual checks.
