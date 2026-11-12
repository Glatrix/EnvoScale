# `envo.math`

> **Status:** Experimental (M11.1). Tests: `lib/envo/math/tests/`. Scalar float functions
> are in `core.math`.

Vectors, matrices and quaternions for graphics (PLAN D53), in `f32`:
- matrices are column-major and act on column vectors;
- the world is right-handed (y up, the camera looking down −z);
- clip-space depth runs from 0 (near) to 1 (far), as Direct3D, Vulkan and WebGPU use.

## Simple door

```envo
use envo.math;

math.Vec3 a = math.Vec3.Of(1.0, 2.0, 3.0);
math.Quat q = math.Quat.Axis(math.Vec3.Up(), math.Radians(90.0));
math.Vec3 turned = q.Rotate(a);
```

## Full-control door

- `Vec2`, `Vec3`, `Vec4`: `Add`, `Sub`, `Mul`, `Scale`, `Dot`, `Cross`, `Length`,
  `Normalize`, `Lerp`, `Reflect`.
- `Quat`: `Axis`, `Mul`, `Rotate`, `Normalize`, `Slerp`.
- `Mat4`: `Identity`, `Translate`, `Scaling`, `Rotation`, `Trs`, `Perspective`,
  `LookAt`, `Mul`, `MulVec4`, `TransformPoint`, `TransformDir`, `Transpose`, `Inverse`.
- `Radians(degrees)`.

## Ports used

None.
