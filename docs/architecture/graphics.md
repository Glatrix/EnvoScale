# Graphics and UI (M8)

> **Status:** M8, in progress. Decisions D43–D47 in [`PLAN.md`](../PLAN.md).

M8 builds the screen side of the platform from the bottom up. A terminal and a window
are ports, and everything drawn is computed in memory first:

| Layer | Module | State |
|---|---|---|
| Terminal port (D43) | `ports.ITerminal`, adapters in `os.*` | done (8.1) |
| Terminal programs | `envo.term`: styles, keys, a diffing cell screen | done (8.1) |
| Command-line programs | `envo.cli` | done (8.2) |
| 2D drawing (D44) | `envo.gfx`: an RGBA canvas, in software | done (8.3) |
| Text | `envo.font`: TrueType, anti-aliased | done (8.4) |
| Window port (D45) | `ports.IWindow`, adapters in `os.*` | done (8.5) |
| UI (D47) | `envo.ui` | 8.6 |
| GPU (D46) | `envo.gpu` | 8.7, 8.8 |

## Exact arithmetic

Envo-S1 has no floating point yet, so rasterization is integer and fixed point:

- `envo.gfx` measures edge coverage on a 4 × 4 grid in each pixel.
- `envo.font` flattens curves at 1/256 pixel and measures coverage exactly across each
  pixel on four sub-rows.

Every result is the same on every machine and in every build mode (`-O0`, `-O2`, the
script runtime). That makes golden tests possible: a test compares a SHA-256 of the
pixels, or the coverage drawn as text.

## The Terminal port (D43)

`ITerminal`: `IsTerminal`, `Cols`, `Rows`, `Raw(on)`, `Write`, `Read(into, waitMs)`.

| Adapter | How |
|---|---|
| `os.none` | In memory, with a size given (`Sized`): output kept (`Output`), input typed (`Type`), `Resize`. |
| `os.windows` | The console API (a second KERNEL32 descriptor, slots 51–55): VT output processing and UTF-8 output on first use. Raw mode sets VT input, so keys arrive as the escape sequences a Linux terminal sends and one decoder serves both. Timed reads wait on the input handle and read key records. Input that is a pipe is polled with `PeekNamedPipe` (slots 59, 60). |
| `os.linux` | `ioctl` (`TCGETS`, `TCSETS`, `TIOCGWINSZ`) and `poll`. Raw mode clears `ICANON`, `ECHO`, `ISIG`, `IEXTEN` and the input translations, and keeps output processing. |

## The Window port (D45)

`IWindow`: `Open(title, width, height)`, `IsOpen`, `Width`, `Height`, `Poll` (an `Event`:
close, resize, key down and up, character, mouse move, buttons, wheel), `Present(rgba,
width, height)`, `SetTitle`, `Close`.

The Win32 adapter needs no callback from Windows into Envo code. Its window class uses
`DefWindowProcW` itself as the window procedure, so:
- events are read from the message queue (`PeekMessageW`, then `TranslateMessage` for
  characters and `DispatchMessageW`);
- a window the user closed is one that no longer exists (`IsWindow`);
- a new size is seen by asking for the client area each `Poll`.

Frames go to the screen with `SetDIBitsToDevice` (top-down, 32-bit BGRA, converted from
RGBA). The process is marked DPI-aware, so a pixel is a pixel. Windows enforces a
minimum window width, so `Width` may be larger than asked for.

Two calls take 12 arguments (`CreateWindowExW`, `SetDIBitsToDevice`). For them,
`__wincall12` passes the slot and 12 arguments, and is the same `wincall` intrinsic in
EIR ([`library.md`](library.md)).

`os.none` is an off-screen window. It keeps the last frame (`Frame`) and gives the events
a test queued (`Queue`). Linux windows (X11, Wayland) come after M8: the Linux adapter's
`Open` says no.

In the script runtime the window calls need `--allow all`: a window class names a
function for Windows to call, which the sandbox cannot check
([`script-runtime.md`](script-runtime.md)).

## Fonts

`envo.font` reads TrueType outlines from the system's fonts (`System("sans-serif")`).
Envo bundles none. Font files are treated as untrusted input:
- every read is checked;
- composite glyphs nest at most 8 deep;
- a glyph has at most 65,536 points;
- the tests parse every truncation of the test font, and the font with each byte changed.
