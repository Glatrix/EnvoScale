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
| Window port (D45) | `ports.IWindow`, adapters in `os.*`: Win32, X11 (14.7), a page's canvas (14.8) | done (8.5, 14.7, 14.8) |
| UI (D47) | `envo.ui` on `envo.lumen`; application components on `envo.edit` | done (8.6, 14.6) |
| Input and clipboard (D73) | `ports.KEY_*`, `Event.Mods`, `ports.IClipboard`, `std.clipboard` | done (14.2) |
| GPU port (D46) | `ports.IGpu`; software adapter in `envo.gpu`, Direct3D 12 in `os.windows` | done (8.7, 8.8) |

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

Input is in EnvoScale's terms (PLAN D73): key codes are `ports.KEY_*` and every key,
character and mouse event carries the modifier keys held (`Event.Mods`, `MOD_SHIFT`,
`MOD_CTRL`, `MOD_ALT`, `MOD_META`). The codes match Win32's virtual keys, so the Windows
adapter passes them through; other adapters translate. The Clipboard port
(`ports.IClipboard`, `std.clipboard`) holds text: Windows' through `CF_UNICODETEXT`, the
reference adapters' in memory, the browser host's within the page (and written to the
system's where the browser allows), and Linux's is the X server's `CLIPBOARD` selection
(M14.7b): a connection of the clipboard's own, made on first use and kept for the
program's life, owns the selection to copy (answering other programs' requests for
`UTF8_STRING`, `STRING` and `TARGETS`) and converts it to paste. A window's `Poll`
answers those requests, so a program with no window answers only when it next uses the
clipboard. CI copies and pastes both ways with `xclip` under Xvfb.

The Win32 adapter needs no callback from Windows into Envol code. Its window class uses
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
a test queued (`Queue`).

Linux windows (M14.7) speak X11 to the server `$DISPLAY` names, over its Unix socket
(`/tmp/.X11-unix/X<n>`), with no Xlib: `os.linux.x11` is a core-protocol client of a few
hundred lines. It authenticates with the `MIT-MAGIC-COOKIE-1` for that display from the
Xauthority file (`$XAUTHORITY`, else `~/.Xauthority`), reads the keyboard map
(`GetKeyboardMapping`) to turn key codes into keysyms, and from those into `KEY_*` codes
and typed characters (Latin-1 and Unicode keysyms). The window asks for
`WM_DELETE_WINDOW`, so closing it is an event, not a broken connection. Frames go up with
`PutImage` (ZPixmap, depth 24, BGRX) in strips of rows that fit the server's request
size. Buttons 4 and 5 are the wheel. An error from the server ends the window: `Poll`
reports `Close`. With no X server, `Open` says no. CI runs the Linux suites under Xvfb, so
the window conformance suite opens a real window there. Wayland comes later.

In the script runtime the window calls need `--allow all`: a window class names a
function for Windows to call, which the sandbox cannot check
([`script-runtime.md`](script-runtime.md)).

## The GPU port (D46)

`IGpu`: `Name`, `Begin(width, height, clear)`, `Triangles(vertices)`, `End()`. `End` gives
the frame's RGBA pixels. A vertex is a position in whole pixels and a color, 0xRRGGBBAA.
Frames are drawn off-screen and read back, and a window presents them like any other
pixels. Every adapter follows the same rules:
- a pixel is covered when its centre is inside a triangle;
- the top-left rule decides edges, so triangles sharing an edge cover each pixel once;
- colors are interpolated linearly;
- blending is source-over: color `src·a + dst·(1−a)`, alpha `a + dst·(1−a)`.

`tests/conformance/gpu` checks each adapter against the software adapter: every channel
of every pixel must agree to within 1, since GPUs round colors slightly differently.

| Adapter | How |
|---|---|
| `envo.gpu.Software` | Edge functions in half pixels, colors interpolated exactly and rounded. `platform.Gpu()` on Linux and with `--os none`. |
| `os.windows.Gpu` | Direct3D 12 on the first hardware adapter (DXGI). HLSL compiled at run time by the system's `D3DCompile`, so no shader binaries are checked in. Vertices go up in an upload buffer, the frame's size as two root constants. The frame is drawn into an RGBA8 render target, copied to a read-back buffer and waited for with a fence. Without a hardware adapter, or in the sandbox, it draws in software. |

Direct3D is reached through `__wincallp`: `GetProcAddress` for the DLLs' exported
functions, and the objects' method tables for COM. Floats the driver needs (the clear
color, the viewport) are built bit by bit from integer ratios.

### Compute (D61)

`MatMul(a, b, m, k, n, into)` multiplies an m × k matrix by a k × n one (row-major `f32`).
The software adapter sums each element in order of k (`envo.gpu.MatMulCpu`, the
reference). The Direct3D 12 adapter runs an HLSL compute shader (8 × 8 threads per group,
one per element of the result) on a second pipeline: three root constants (m, k, n), the
inputs as root shader-resource views into one upload buffer, the result as a root
unordered-access view into a default buffer, copied to a read-back buffer. GPUs may fuse
multiplies and adds, so results agree with the CPU's to a relative 1e-4, not bit for bit
(`tests/conformance/gpu`). Wrong sizes are refused and leave the output alone.
`envo.ai.MatMulOn` uses it.

Vulkan (for Linux GPUs) comes after M8, with Linux windows. It needs SPIR-V shaders,
which have no runtime compiler on the system.

## UI (D47)

`envo.ui` keeps the interface as a tree in one list (each component knows its parent,
first child and next sibling). Envo-S1 cannot store closures, so components return what
was activated instead of calling handlers.

Layout is one pass over the tree in two steps. Measuring goes bottom up: text through
the font in pixels, or by code points in cells. Arranging goes top down: a container
shares the space left over among the children that grow, then places them across by
its alignment.

Spacing is given as Lumen steps, so the same tree lays out in pixels or in cells; a
terminal rounds the steps to cells. Both renderers draw the same roles: a card's
rounded surface and edge become a box of lines, and the focus ring becomes reverse
video.

## Fonts

`envo.font` reads TrueType outlines from the system's fonts (`System("sans-serif")`).
Envol bundles none. Font files are treated as untrusted input:
- every read is checked;
- composite glyphs nest at most 8 deep;
- a glyph has at most 65,536 points;
- the tests parse every truncation of the test font, and the font with each byte changed.
