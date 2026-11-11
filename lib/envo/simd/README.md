# `envo.simd`

> **Status:** Not started. Planned for **M4**. Tier when it lands: Experimental.

Portable SIMD types (`f32x8`, …) with scalar fallbacks, CPU feature queries, and `[Multiversion]` support.

## Simple door

```envo
var v = simd.f32x8.Splat(1.0) * 2.0;
```

## Full-control door

Per-target intrinsics behind `[TargetFeature]`.

## Ports used

none (CPU features are queried through the target description)
