# `envo.lumen`

> **Status:** Experimental (M8.6). Tests: `lib/envo/lumen/tests/`. Spec:
> [`docs/lumen/`](../../../docs/lumen/README.md).

The Lumen design language's tokens as typed values: color roles for a light and a dark
scheme, the type scale, the 4-pixel spacing scale, corner radii, control metrics and
motion durations. [`tokens.envon`](tokens.envon) is the source; `Light()` and `Dark()` hold
the same values, and the tests check that they agree. Every color pair the spec promises
meets WCAG 2.2 AA contrast.

## Simple door

```envo
use envo.lumen;

lumen.Theme th = lumen.Dark();
u32 accent = th.C.Accent;      // 0xRRGGBB
```

## Full-control door

A theme is a plain value: change any field. `FromTokens(eonText, "light" | "dark")`
reads tokens in `tokens.envon`'s shape over Lumen's own, so a program can ship its own
token file. `Describe()` lists every value.

## Ports used

None.
