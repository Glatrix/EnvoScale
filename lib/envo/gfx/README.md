# `envo.gfx`

> **Status:** Not started. Planned for **M8**. Tier when it lands: Experimental.

2D graphics: paths, Béziers, fills/strokes, gradients, anti-aliasing, clipping, blending, images, text, blur/vibrancy, and a retained compositor. GPU-accelerated when available, software otherwise.

## Simple door

```envo
window("Hi") { canvas(c => c.Circle(100, 100, 50, Lumen.Accent)) }
```

## Full-control door

Explicit render targets, layer caching control, custom shaders through `envo.gpu`.

## Ports used

GpuDevice, Window
