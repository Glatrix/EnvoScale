# Lumen design language

> **Status:** Version 1 (M8.6). Tokens: [`lib/envo/lumen/tokens.envon`](../../lib/envo/lumen/tokens.envon);
> code: `envo.lumen`; used by `envo.ui` as its default theme.

Lumen is how Envol programs look by default: calm surfaces, one accent color, type on the
system's own fonts, and generous, regular spacing. A theme is a set of token values; a
program can override any of them.

## Principles

1. **Content first.** Surfaces are quiet: near-white or near-black backgrounds, raised
   panels a step lighter or darker, one accent color for what can be acted on.
2. **One grid.** Every distance is a step of 4 pixels; a terminal rounds them to cells.
3. **Readable by default.** Text and controls meet WCAG 2.2 AA contrast in both
   schemes: 4.5:1 for body text, 3:1 for large text and control edges.
4. **Visible focus.** The focused control always shows a focus ring in the accent color.
5. **Same meaning everywhere.** Desktop and terminal renderers use the same roles; a
   terminal gets the nearest colors it can show and draws edges as lines.

## Color roles

Each role has a light and a dark value (`tokens.envon`, blocks `light` and `dark`).

| Role | Use |
|---|---|
| `background` | the window behind everything |
| `surface` | panels and cards on the background |
| `surfaceRaised` | controls (buttons, fields) and anything above a surface |
| `surfacePressed` | a control while it is pressed |
| `text` | body text, titles |
| `textSecondary` | captions, hints, disabled text |
| `separator` | lines between groups (decorative) |
| `controlEdge` | the edge of a control (a field, a checkbox, a secondary button): 3:1 against what is around it |
| `accent` | the primary action, links, the focus ring, a checked box |
| `accentHover` | the accent under the pointer |
| `onAccent` | text and marks on the accent |
| `danger`, `success`, `warning` | states; each passes 3:1 against `surface` |

## Type

On the system's sans-serif font (`envo.font.System`). Sizes in pixels, each with its line
height; in a terminal every style is one cell high, and titles are bold.

| Style | Size | Line | Weight in a terminal |
|---|---|---|---|
| `caption` | 12 | 16 | normal |
| `body` | 15 | 20 | normal |
| `headline` | 17 | 24 | bold |
| `title` | 22 | 28 | bold |
| `largeTitle` | 28 | 36 | bold |

## Space, shape and motion

- Spacing: `xs` 4, `s` 8, `m` 12, `l` 16, `xl` 24, `xxl` 32 pixels. A terminal uses no
  cell for `xs` and `s`, one for `m` and `l`, and two for `xl` and up.
- Corners: `small` 6 (checkboxes), `medium` 10 (buttons, fields), `large` 14 (cards).
- Control height: 32 pixels on the desktop, 1 cell in a terminal (3 with a box).
- Focus ring: 2 pixels of `accent`, outside the control's edge.
- Motion: `fast` 120 ms and `normal` 200 ms, eased out. Programs show no motion when the
  system asks for reduced motion. (M8 draws no animation yet.)
