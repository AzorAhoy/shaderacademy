# 3D Axes and UV Coordinate Conventions

This guide describes the conventions visible in this repository's examples.
The repository contains shader and mesh lessons, not a complete renderer:
camera setup, texture upload, and GPU bindings are supplied by the host application.
Do not infer those settings from GLSL syntax alone.

## 1. Quick reference

| Quantity | Convention in the examples |
| --- | --- |
| Position | `(x, y, z)` in mesh-local units, transformed to world space |
| Vertical axis | Y: positive is up, negative is down |
| Horizontal plane | XZ |
| Forward direction | Not specified globally; depends on object and camera setup |
| Handedness | Not specified globally by the supplied camera/renderer code |
| UV | `(u, v)`, independent of 3D axes |
| Cube UVs | A full `[0, 1]` square on every face |
| Lathe UVs | U goes around the vase; V goes from bottom to top |
| Texture image orientation/wrapping | Host application settings, not defined by the sampling shader |

## 2. Understanding the 3D axes

Y is height in the [lathe mesh](./procedural_mesh_basics/lathe_1/scene.ts):

```ts
const t = row / rows;
const y = (t - 0.5) * height;
mesh.vertices.push(radius * cos, y, radius * sin);
```

For `height = 11`, the bottom is `y = -5.5` and the top is `y = +5.5`.
The circular cross-sections lie in XZ, rotating around Y.

```text
                  +Y (up)
                   |
                   |
                   O---------- +X
                  /
                 /
               +Z

Schematic only: the on-screen directions of X and Z depend on the camera.
```

The [cube mesh](./procedural_mesh_basics/procedural_mesh_7/scene.ts) is centered
at the local origin `(0, 0, 0)`. Its coordinates run from `-2` to `+2` on each
axis, so each edge is 4 mesh units long. No conversion to meters is specified.
Its six face normals point along `+X`, `-X`, `+Y`, `-Y`, `+Z`, and `-Z`.
An outward face normal describes which way the face points, not where the camera is.

**Right/left and toward/away are camera-relative.** It is not safe to say
"positive Z is always toward the viewer" or "positive X is always screen-right."
Likewise, Y-up alone does not establish a left- or right-handed camera convention.
The interactive demo below explicitly uses its own right-handed camera.

### Local axes versus world axes

In the [procedural vertex shader](./procedural_mesh_basics/procedural_mesh_7/vert.glsl),
the transformation is:

```glsl
vec4 worldPos = instanceWorld * vec4(position, 1.0);
gl_Position = projection * view * worldPos;
```

Read this from right to left:

```text
local position -> instance/world transform -> camera view -> projection
               -> clip space -> perspective divide -> screen
```

Rotating an instance rotates its local axes in the world. The UV values do not
rotate with the camera; they remain attached to the mesh vertices.
Lighting vectors and normals must be in compatible spaces. The examples use
`mat3(world) * normal` (or its instance equivalent); non-uniform scaling generally
requires an inverse-transpose normal matrix instead.

### Rotation axes and signs in the transform lessons

The [transformation lessons](./transforms/README.md) rotate local positions
before applying the world and camera transforms. Their GLSL matrix constructors
are filled by **columns**, and positions are multiplied as column vectors.
For a positive 90-degree shader angle:

| Rotation | Unchanged axis | Example local direction |
| --- | --- | --- |
| [Y](./transforms/transform_2/vert.glsl) | Y | `+X` becomes `+Z` |
| [X](./transforms/transform_4/vert.glsl) | X | `+Y` becomes `-Z` |
| Z | Z | `+X` becomes `-Y` in the guide's illustrative matrix |

These X and Y matrices, and the guide's illustrative Z matrix, correspond to
active right-handed rotations by **negative** shader angle in a conventional
right-handed XYZ basis. The Z matrix is a reference example, not a separate
lesson shader. This algebraic comparison does not establish a global camera
handedness or a clockwise screen direction; the view determines what you see.

The [transformation explorer](./transforms/transform-demo.html) compares
local-space shapes under the X/Y matrices. Its orthographic view and identity
world transform are teaching choices, not renderer defaults.

### Position-dependent local deformations

[Tapering](./transforms/transform_8/CODE_EXPLANATION.md) uses local Z to
scale local Y about `y = 0`: `y' = y * (1 + 0.95 * z)`. X and Z remain
unchanged. For a cube spanning `z = -1` to `1`, the factor changes from
`0.05` to `1.95`; a different local Z range changes the result. The factor
is zero at approximately `z = -1.0526`, and negative below it.

[Twisting](./transforms/transform_10/CODE_EXPLANATION.md) rotates local XZ
by an angle dependent on local Y and time. It preserves each vertex's distance
from local Y but does not rotate the entire mesh rigidly. For both effects,
transform the deformed local point to world space for lighting as well as to
clip space for display. Surface normals also need to account for the local
deformation; lesson 10's normal rotation alone is an approximation.

## 3. UV coordinates are a separate 2D system

Each vertex has two UV values in addition to its three position values.
U is the first component (`uv.x`), and V is the second (`uv.y`).
They are not automatically copied from world X and Y.

Use this mathematical chart when reading the examples:

```text
      V
      ^
  1   (0,1)----------------(1,1)
      |                      |
      |        (0.5,0.5)     |
      |                      |
  0   (0,0)----------------(1,0) -> U
      0                      1
```

This chart displays increasing V upward. It does **not** prove which row of an
uploaded image will appear at V = 0: image decoding, upload flipping, and the
host texture setup determine that. Use a labeled test image to check orientation.

### Cube: a separate UV square on every face

The [quad helper](./procedural_mesh_basics/procedural_mesh_7/scene.ts) assigns
UVs to its four corners in this order:

```ts
const uvs: number[] = [
    0, 0, // corner 0
    1, 0, // corner 1
    1, 1, // corner 2
    0, 1, // corner 3
];
```

Triangles use indices `(0, 1, 2)` and `(0, 2, 3)`. UV entries must correspond
to the same vertex indices as the positions. Each cube face has its own vertices,
so shared geometric corners can have different UVs and normals on adjacent faces.
The image covers each face independently; this is not a six-face texture atlas.

On the **positive-Z face**, the actual mapping is:

```text
(-2,+2,+2) UV(0,1) -------- (+2,+2,+2) UV(1,1)
          |                          |
(-2,-2,+2) UV(0,0) -------- (+2,-2,+2) UV(1,0)
```

Here U follows +X and V follows +Y. That is not universal: on the positive-X
face U follows -Z, while on the positive-Y face V follows -Z.
Read each face's corner order rather than assuming UV axes always match world axes.

### Lathe: unwrap a ring into a horizontal strip

The [lathe mesh](./procedural_mesh_basics/lathe_1/scene.ts) assigns:

```ts
const u = segment / segments;
const angle = Math.PI / 4 + u * Math.PI * 2.0;
mesh.vertices.push(radius * Math.cos(angle), y, radius * Math.sin(angle));
mesh.uvs.push(u, t);
```

- **U = 0 to 1:** one complete revolution, starting at an angle of 45 degrees.
- **V = t = 0 to 1:** bottom to top.
- At constant height, increasing U moves from +X toward +Z as the angle increases.
- U = 0 and U = 1 share the same physical seam position, but use separate vertices
  so the UVs interpolate across the surface instead of jumping through the seam.
- Equal UV distances do not necessarily represent equal physical distances:
  the radius varies, and V tracks height rather than distance along the curved profile.

The [lathe fragment shader](./procedural_mesh_basics/lathe_1/frag.glsl) uses
`fract(v_uv.y * 6.0)` for six horizontal band cycles and
`fract(v_uv.x * 16.0)` for sixteen stripe cycles around the vase.
Those are procedural colors; that shader does not read an image texture.

## 4. From mesh UVs to a sampled color

```text
mesh.uvs -> vertex attribute uv -> vertex output v_uv
         -> GPU interpolation across a triangle
         -> fragment input v_uv -> texture(u_texture, v_uv)
```

The [vertex shader](./procedural_mesh_basics/procedural_mesh_7/vert.glsl)
passes `v_uv = uv`. The
[fragment shader](./procedural_mesh_basics/procedural_mesh_7/frag.glsl) samples
`u_texture` using that interpolated value. Normal smooth varyings use
perspective-correct interpolation.

The host must upload the UV buffer, bind a texture, and set its sampler.
Wrapping outside `[0, 1]`, filtering, mipmaps, image flips, and color-space handling
are not specified by these shaders. For image tiling, prefer configured repeat
wrapping over manually applying `fract` when possible; `fract` can create
derivative seams. See the [sampling snippets](./CODE_SNIPPETS.md).

### Special case: parallax mapping

The [parallax shader](./materials/parallax_2/frag.glsl) assumes a flat plane
with tangent = +X, bitangent = +Z, and normal = +Y. In that lesson, tangent-space
X/Y represent the surface directions used for the UV displacement, and
tangent-space Z is the surface-normal direction, not world Z.
It offsets the sampling UVs to simulate relief without moving the vertices.
Do not reuse this fixed surface frame on arbitrary rotated or curved meshes.

## 5. Visual and interactive demonstration

Open [the coordinate demo](./docs/coordinate-demo.html) directly in a modern
browser from your local checkout. No install, server, network access, or build is
required. If reading the published notebook, get the HTML from the
[repository](https://github.com/AzorAhoy/shaderacademy/blob/HEAD/docs/coordinate-demo.html)
and open the downloaded file locally; the demo is not bundled into the notebook.

Try these experiments:

1. Orbit the cube with the yaw and elevation controls. Y remains world-up while
   the on-screen directions of X and Z change.
2. Click the UV chart or change U/V. The matching yellow point appears on the
   cube's positive-Z face. Rotate the camera if that face is behind the cube.
3. Switch to the lathe. V moves the point up/down; U moves it around the vase.
   Compare U = 0 and U = 1 to see the seam.
4. Increase checker repeats, then flip sampled V. The checker pattern changes,
   but the mesh and selected UV location do not. This illustrates a sampling
   transform, not a change to the authored UV buffer.

The demo is a CPU-projected Canvas illustration, not the project's host renderer.
It uses the cube face corner order and the lathe radius/UV formulas from the
lessons. Its right-handed camera and labeled checker are explicit teaching
choices, not evidence of renderer defaults. The selected point is drawn as an
overlay even when it is on the far side of the mesh.

## 6. Debugging checklist

- **Image upside down?** Check a labeled image and host upload/flip settings;
  do not change mesh UVs and upload flipping at the same time.
- **Image rotated on one cube face?** Check that face's corner-to-UV order.
- **Texture slides as the camera moves?** Check that you use mesh UVs rather
  than screen coordinates for a surface-attached texture.
- **Stretched checker cells?** Compare UV distance with physical surface distance.
- **Visible lathe seam?** Check the duplicated seam vertices, image edge continuity,
  sampler wrapping, and filtering.
- **Deferred lighting misaligned?** Screen UVs used for G-buffer sampling are not
  object UVs. Render targets must agree on dimensions and orientation; see
  [G-buffer reconstruction](./g_buffer/gbuffer_5/CODE_EXPLANATION.md).
