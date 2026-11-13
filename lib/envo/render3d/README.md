# `envo.render3d`

> **Status:** Experimental (M11.3–M11.5). Tests: `lib/envo/render3d/tests/`.

3D scenes, rendered in software (PLAN D55).
- **Scene:** an `envo.ecs` world of objects with a transform, a mesh and a material, lit
  by sun (directional) and point lights, seen by a camera.
- **Rendering:**
  - triangles are clipped at the near plane;
  - they are rasterized with a depth buffer and perspective-correct interpolation;
  - each pixel is shaded physically: Cook-Torrance with a GGX distribution, Smith-Schlick
    geometry and Schlick's Fresnel, under a hemispheric sky and ground;
  - the frame is tone-mapped (ACES) into sRGB.
- **Determinism:** all of it is IEEE arithmetic in Envol, so a frame is the same bit for
  bit at `-O0` and `-O2`, in WebAssembly and in the script runtime. The tests compare its
  hash.

## Simple door

```envo
use envo.render3d;
render3d.Show(render3d.Scene.New().Cube().Spin().Sun(), "Hello");
```

## Full-control door

- `Scene`: `Add(mesh, material, position)` (an entity), `AddLight`, `SetCamera`,
  `SetTransform`, `SetSpin`, `Step(seconds)`. Its stores (`Transforms`, `MeshOf`,
  `Materials`, `Spins`) are `envo.ecs` stores, open to the program's own systems.
- `Mesh`: `Cube`, `Sphere(rings, segments)`, `Plane(size)`, or `Vertex` and `Triangle`
  for any other.
- `Material`: `Of(linear color, metallic, roughness)`, `Rgb(0xRRGGBB, …)` (sRGB).
- `Light`: `SUN` (a direction) or `POINT` (a position), with a color times intensity.
- `Render(scene, width, height)` gives an `envo.gfx` canvas. `Show(scene, title)` runs it
  in a window.

## glTF 2.0 (`envo.render3d.gltf`)

`gltf.Load(path)` reads a `.gltf` document with its buffers, from `.bin` files beside it
or base64 `data:` URIs (D56). `gltf.Parse(text)` reads a document whose buffers are all
`data:` URIs. Either gives an `Import`, and `AddTo(ref scene)` puts its parts in a scene.
- **Meshes:** triangle primitives with positions, normals (computed from the faces when
  absent) and 8-, 16- or 32-bit indices.
- **Materials:** the metallic-roughness factors.
- **Nodes:** the default scene's node hierarchy, with translation, rotation and scale, or a
  matrix.

A file is untrusted input. Every index and byte range is checked, and node nesting is
limited, so a malformed document gives an error.

## Not yet

GLB files, textures and image-based lighting, shadows, anti-aliasing, skinning
and animation, and drawing through `envo.gpu` (Direct3D 12).

## Ports used

Window (`Show`).
