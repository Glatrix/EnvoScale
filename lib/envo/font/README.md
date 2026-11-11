# `envo.font`

> **Status:** Not started. Planned for **M8**. Tier when it lands: Experimental.

TrueType/OpenType parsing, rasterization and text shaping (basic first, complex scripts later). No bundled third-party fonts.

## Simple door

```envo
var face = font.System("sans-serif");
```

## Full-control door

Glyph-level access, hinting control, custom shapers.

## Ports used

FontSource
