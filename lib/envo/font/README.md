# `envo.font`

> **Status:** Experimental (M8.4). Tests: `lib/envo/font/tests/`.

TrueType fonts: the tables a renderer needs (`head`, `hhea`, `maxp`, `cmap` formats 4
and 12, `hmtx`, `loca`, `glyf` with simple and composite glyphs) and an anti-aliased
rasterizer. Curves are flattened in fixed point (1/256 pixel), and coverage is measured
exactly across each pixel on four sub-rows with the non-zero winding rule. Envo bundles
no fonts: `System` finds the system's own.

A font file is untrusted input. Every read is bounds-checked, composite glyphs nest at
most 8 deep, and a glyph has at most 65,536 points. The tests parse every truncation of
the test font, and the font with each byte changed.

## Simple door

```envo
use envo.font;
use envo.gfx;

font.Font f = font.System("sans-serif").Unwrap();
gfx.Canvas c = gfx.Canvas.New(400, 60);
c.Clear(gfx.Color.Hex("#ffffff"));
f.Draw(ref c, 10, 40, "Hello, World!", 32, gfx.Color.Hex("#1d1d1f"));
```

## Full-control door

- `Font.Parse(bytes)`, `Font.ParseText(text)`, `Load(path)`, `System(family)` for
  "sans-serif", "serif" and "monospace".
- Metrics: `UnitsPerEm`, `Ascent`, `Descent`, `LineGap`, `LineHeight(px)`,
  `GlyphCount`, `GlyphIndex(codePoint)`, `Advance(glyph)`, `Measure(text, px)`.
- `Render(glyph, px, shift)` gives a `Mask` (alpha, with its offset from the pen);
  `shift` positions the glyph at 1/256-pixel steps. `Draw(ref canvas, x, baseline,
  text, px, color)` lays out a line.

## Not yet

OpenType CFF outlines (`.otf`), font collections (`.ttc`), kerning (`kern`, `GPOS`),
hinting, shaping for complex scripts, and wide-character measurement in `envo.term`.
Glyphs are rendered each time they are drawn; a cache comes with `envo.ui`.

## Ports used

FileSystem (through `std.fs`), for `Load` and `System`.
