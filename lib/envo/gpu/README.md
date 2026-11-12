# `envo.gpu`

> **Status:** Experimental (M8.7, M8.8). Tests: `lib/envo/gpu/tests/`,
> `tests/conformance/gpu/`.

The GPU port (`ports.IGpu`, PLAN D46) draws frames of colored triangles off-screen and
reads them back. This module holds the software adapter, which every device has, and
helpers for building frames. `platform.Gpu()` gives the best adapter: Direct3D 12 on a
Windows machine with a GPU, software elsewhere.

## Simple door

```envo
use ports.{IGpu, Vertex};
use envo.gpu;
use platform;

var dev = platform.Gpu();
List<Vertex> v = List<Vertex>.New();
gpu.Gradient(ref v, 0, 0, 640, 480, 0x0A66D8FF, 0x4C9BFFFF);
gpu.Triangle(ref v, Vertex.At(100, 400, 0xFF2D55FF), Vertex.At(320, 60, 0x30D158FF), Vertex.At(540, 400, 0xFFB340FF));
dev.Begin(640, 480, 0xF5F5F7FF);
dev.Triangles(v.AsSlice());
List<u8> frame = dev.End();     // RGBA; a window's Present takes it
```

## Full-control door

- `Software`: the CPU adapter, exact and the same on every machine.
- `Rect`, `Gradient`, `Triangle` append vertices; `Differing(a, b, tolerance)` compares
  frames as the conformance suite does.

## Not yet

Textures, index buffers, shaders written by programs, compute, a swap chain (frames are
read back), and the Vulkan adapter (after M8, with Linux windows). The software adapter
draws without anti-aliasing, as GPUs do without multisampling.

## Ports used

Gpu (`ports.IGpu`).
