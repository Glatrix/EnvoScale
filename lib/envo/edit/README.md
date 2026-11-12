# `envo.edit`

> **Status:** Experimental (M14.5). Tests: `lib/envo/edit/tests/`.

The editor core (PLAN D74): a text buffer with any number of selections, editing,
movement, undo and redo, and search. It has no UI: `envo.ui`'s code editor draws a
`Buffer` and turns keys into calls on it, and the tests drive it directly. Nothing here
touches a port, so it runs the same natively, in the VM and in a page.

## Simple door

```envo
use envo.edit;

edit.Buffer b = edit.Buffer.Of("fn Main() {}");
b.SetCursor(edit.Pos.At(0, 11));
b.Newline();                    // the new line keeps the indentation
b.Insert("print(\"hi\");");
b.Undo();
print(b.Text());
```

## Positions and selections

- A `Pos` is a line (from 0) and a byte column, always on a character boundary.
  `VisualCol` gives the column it is drawn at (characters, tabs to the next tab stop).
- A `Selection` runs from `Anchor` to `Head` (the cursor). A buffer always has at least
  one; `AddCursor` and `AddSelection` add more, and selections that touch merge.
- `Move(motion, extend, page)` moves every cursor by a `MOVE_*` motion: characters,
  words, lines (keeping a goal column across short lines), Home (to the indentation, then
  the line's start), End, the top and bottom, and pages. With `extend` the selections
  grow instead.

## Editing

| Call | What it does |
|---|---|
| `Insert(t)` | types `t` at every selection; characters typed one after another undo together |
| `Newline()` | a line break, indented as the line it leaves |
| `Backspace()`, `Delete()` | the selections, or one character (backspace in indentation goes back to the tab stop) |
| `Cut()`, `Copy()`, `Paste(t)` | `Paste` gives each cursor its own line when `t` has one line per cursor |
| `Indent()`, `Dedent()` | spaces to the next tab stop at a cursor; whole lines with a selection |
| `ToggleComment(prefix)` | comments the touched lines out, or back in |
| `Undo()`, `Redo()` | one step each; a step made at several cursors undoes as one |

Every change is a list of replacements, so undo is exact at any number of cursors.

## Search

`Find` (wrapping round, with or without case), `FindAll`, `FindNext`,
`SelectAllMatches` (a selection on each) and `ReplaceAll` (one undo step).

## Line endings

`Buffer.Of` accepts LF and CRLF; `Text()` writes back what it was given (`UsesCrlf`).
