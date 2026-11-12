# `envo.gfx`

> **Status:** Experimental (M8.3). Tests: `lib/envo/gfx/tests/`.

2D drawing on an RGBA canvas, in software (PLAN D44). Shapes have anti-aliased edges
(coverage measured on a 4 x 4 grid inside each edge pixel) and colors blend source-over
with straight alpha. Only integer arithmetic is used, because Envo-S1 has no floats yet,
so coordinates are whole pixels. Every result is exact and the same on every machine,
so tests compare SHA-256 hashes of the pixels (golden images).

## Simple door

```envo
use envo.gfx;

gfx.Canvas c = gfx.Canvas.New(64, 48);
c.Clear(gfx.Color.Hex("#f5f5f7"));
c.FillRoundedRect(4, 4, 56, 40, 10, gfx.Color.Hex("#ffffff"));
c.FillCircle(18, 24, 8, gfx.Color.Hex("#1a73e8"));
c.FillTriangle(32, 34, 56, 34, 44, 12, gfx.Color.Rgba(255, 59, 48, 200));
write(1, c.Ppm().AsStr());   // a P6 image, for looking at
```

## Full-control door

- `Color`: `Rgb`, `Rgba`, `Hex("#rrggbb[aa]")`, `Covered(coverage)`.
- `Canvas`: `New`, `Width`, `Height`, `Pixels` (RGBA bytes, rows from the top), `Get`,
  `Blend` (one pixel), `Clear`, `FillRect`, `StrokeRect`, `Line` (Bresenham),
  `FillCircle`, `FillRoundedRect`, `FillTriangle` (any winding), `Blit`, `Hash`, `Ppm`;
  `SetClip` and `ResetClip` (drawing lands only inside a rectangle; `Clear` ignores it).

## Not yet

Paths and Béziers, strokes wider than a pixel on curves, gradients, clipping, blur.
These come with floats, or as fixed-point additions when `envo.ui` needs them. Text is
`envo.font` (M8.4). The GPU adapters (`envo.gpu`, D46) draw the same commands faster.

## Ports used

None: a canvas is memory. A window (the Window port, D45) presents one.
