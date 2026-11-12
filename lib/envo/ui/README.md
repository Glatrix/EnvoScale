# `envo.ui`

> **Status:** Experimental (M8.6; application components M14.6). Tests:
> `lib/envo/ui/tests/`.

User interfaces as a retained tree of components (PLAN D47). A program builds the tree,
lays it out for a size, draws it, and hands it input; input comes back as the component
that was activated, so the program decides what that means. One layout pass serves two
renderers: pixels (`envo.gfx` and `envo.font`, shown in a window) and cells
(`envo.term`). Lumen (`envo.lumen`) is the theme.

## Simple door

```envo
use envo.ui;
use envo.gfx;
use envo.font;
use envo.lumen;
use ports.{EventKind};
use platform;

lumen.Theme th = lumen.Light();
ui.Tree t = ui.Tree.New();
t.SetPadding(t.Root(), ui.XL);
u32 card = t.Card(t.Root());
t.Text(card, "Settings", ui.TITLE);
u32 dark = t.Checkbox(card, "Dark mode", false);
u32 row = t.Row(card);
t.Spacer(row);
u32 save = t.Button(row, "Save", true);

font.Font f = font.System("sans-serif").Unwrap();
var w = platform.Window();
w.Open("Settings", 420, 240);
gfx.Canvas c = gfx.Canvas.New(420, 240);
while (w.IsOpen()) {
    var e = w.Poll();
    if (e.Is(EventKind.None)) {
        t.LayoutPixels(f, th, 420, 240);
        t.DrawPixels(ref c, f, th);
        w.Present(c.Pixels(), 420, 240);
        continue;
    }
    if (t.OnEvent(e) == save) w.Close();
}
```

In a terminal the same tree is laid out with `LayoutCells(theme, cols, rows)`, drawn
with `DrawCells(ref screen, theme)` and handed keys with `OnKey`.

## Full-control door

- Components: `Column`, `Row`, `Card`, `Text` (Lumen styles `CAPTION` to
  `LARGE_TITLE`), `Button` (primary or not), `Checkbox`, `Spacer`, `Divider`.
- Layout: `SetGap` and `SetPadding` take Lumen spacing steps (`XS` to `XXL`), rounded to
  cells in a terminal; `SetAlign` (`Start`, `Center`, `End`, `Stretch`); `SetGrow`
  shares out the space left over; `SetVisible` hides a component (it takes no space).
  Bounds: `X`, `Y`, `Width`, `Height`.
- State: `SetText`, `SetChecked`, `Checked`, `SetEnabled`, `Focused`, `SetFocus`,
  `MoveFocus`, `HitTest`.
- Input: `OnEvent` (a window event) and `OnKey` (a terminal key) return the component
  something happened to, or 0; `Action()` says what (`ACT_ACTIVATE`, `ACT_SELECT`,
  `ACT_OPEN`, `ACT_TOGGLE`, `ACT_CLOSE`, `ACT_EDIT`, `ACT_CANCEL`) and `Item()` which
  item. Tab and Shift+Tab move the focus where Tab means nothing else; Enter and Space
  press buttons; a click is a press and a release on the same component.

## Application components

For applications such as an IDE (M14.6). Lists, trees and editors draw only the rows in
view, so they stay fast with thousands of items or lines.

| Component | What it is | Input |
|---|---|---|
| `Scroll` | a column taller than its space | the wheel |
| `ListView` | rows of items (`AddItem`, `RemoveItem`, `ClearItems`), one selected | arrows, Home, End, pages, Enter (`ACT_OPEN`); a click selects |
| `TreeView` | nested items (`AddItem` with a depth), opening and closing (`SetOpen`) | as a list; Right opens, Left closes or goes out; Enter or a click toggles an item with children |
| `Tabs` | a row of tabs, closable or not | Left and Right; a click selects, or closes on the mark (`ACT_CLOSE`) |
| `Split` | two panes side by side, or one above the other (`SetRatio`) | dragging the divider |
| `TextField` | one line of text | editing keys; Enter submits (`ACT_OPEN`) |
| `Editor` | a code editor: a gutter of line numbers, highlighting (`SetSyntax`) | below |
| `Palette` | a command palette over items, above everything (`OpenPalette`) | typing filters (characters in order, best first); Enter chooses (`ACT_OPEN`), Escape closes (`ACT_CANCEL`) |

Text fields and editors are `envo.edit` buffers: `Buffer(id)[0]` gives the whole editing
API, `Value` and `SetValue` the text, and `RevealCursor` scrolls the cursor into view.
Editing keys: arrows (Ctrl for words), Home and End (Ctrl for the whole text), the page
keys, Shift to select, Backspace, Delete, Enter (indented), Tab and Shift+Tab (indent),
Ctrl+A, Ctrl+Z, Ctrl+Y (or Ctrl+Shift+Z), Ctrl+C, Ctrl+X, Ctrl+V, Ctrl+D (select the
next match too), and Escape (back to one cursor). A click places the cursor, Shift+click
extends the selection, Alt+click adds a cursor, and dragging selects; pointer work in an
editor is done at the next layout, where the font is at hand.

Copy and paste use a clipboard of the tree's own, or the system's
(`UseSystemClipboard(true)`, through `std.clipboard`).

## Not yet

Images, a grid layout, animation, an accessibility tree, a web renderer (the browser
host, M14.8), multi-line strings and comments in highlighting, and right-to-left text.
Envo-S1 cannot store closures, so components return what happened instead of calling
handlers.

## Ports used

Window and Terminal (through the program); Clipboard (through `std.clipboard`, when
asked).
