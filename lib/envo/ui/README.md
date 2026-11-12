# `envo.ui`

> **Status:** Experimental (M8.6). Tests: `lib/envo/ui/tests/`.

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
  shares out the space left over. Bounds: `X`, `Y`, `Width`, `Height`.
- State: `SetText`, `SetChecked`, `Checked`, `SetEnabled`, `Focused`, `MoveFocus`,
  `HitTest`.
- Input: `OnEvent` (a window event: hover, click as press and release on the same
  component, Tab, Enter and Space) and `OnKey` (Tab, Shift+Tab, arrows, Enter, Space).
  Each returns the component activated, or 0; a checkbox flips as it is activated.

## Not yet

Text input fields, lists and scrolling, images, a grid layout, animation, an
accessibility tree, and a web renderer. These come in M9 (with the website) and later.
Envo-S1 cannot store closures, so components return what was activated instead of
calling handlers.

## Ports used

Window (through the program), Terminal (through the program).
