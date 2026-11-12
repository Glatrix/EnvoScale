# `envo.term`

> **Status:** Experimental (M8.1). Tests: `lib/envo/term/tests/`,
> `tests/conformance/term/`.

Terminal programs (PLAN D43): styles as VT sequences, a decoder that turns the bytes a
terminal sends into keys, and a screen of cells that draws only what changed since the
last frame. The Terminal port (`ports.ITerminal`) carries the bytes. On Windows the
console's VT modes are switched on, so keys arrive as the same sequences a Linux
terminal sends and one decoder serves both. Everything in this module is pure, so its
tests compare the text it produces.

## Simple door

```envo
use envo.term;
use platform;

var t = platform.Terminal();
term.Screen scr = term.Screen.New(t.Cols(), t.Rows());
term.Keys keys = term.Keys.New();
t.Raw(true);
t.Write(term.EnterAltScreen().AsStr());
while (true) {
    scr.Clear();
    scr.Box(0, 0, 30, 5, term.Style.Plain());
    scr.Put(2, 2, "Press q to quit", term.Style.Plain().Bold().Fg(0x1a73e8));
    scr.Present(ref t);
    term.Key? k = term.ReadKey(ref t, ref keys, -1);
    if (k.IsSome() && k.Unwrap().IsChar('q' as u32)) break;
}
t.Write(term.LeaveAltScreen().AsStr());
t.Raw(false);
```

## Full-control door

- `Style`: `Plain`, `Fg`, `Bg` (24-bit), `Bold`, `Dim`, `Italic`, `Underline`,
  `Reverse`, `Sgr`; `Styled(text, style)` for output that is not a screen.
- Sequences: `MoveTo`, `ClearScreen`, `HideCursor`, `ShowCursor`, `EnterAltScreen`,
  `LeaveAltScreen`.
- `Keys`: `Feed`, `FeedText`, `Next(final)` gives `Key?`; a lone Escape waits for the
  rest of a sequence until `final`. `ReadKey(ref terminal, ref keys, waitMs)` does the
  waiting.
- `Key`: `Kind` (`KeyKind`: `Char`, `Enter`, `Tab`, `BackTab`, `Backspace`, `Escape`,
  arrows, `Home`, `End`, `PageUp`, `PageDown`, `Insert`, `Delete`, `Function`), `Char`,
  `Ctrl`, `Alt`, `Shift`, `Is`, `IsChar`, `IsCtrl`, `Name`.
- `Screen`: `New`, `Resize`, `Invalidate`, `Clear`, `Set`, `Put`, `Fill`, `Box`,
  `CharAt`, `Render` (the text from the last frame to this one), `Present`, `Text`.

## Limits

Each code point takes one cell: wide (East Asian) characters and combining marks are not
measured yet. Mouse input is not decoded. The reference adapter (`os.none`) is an
in-memory terminal of a given size, for tests.

## Ports used

Terminal (`ports.ITerminal`).
