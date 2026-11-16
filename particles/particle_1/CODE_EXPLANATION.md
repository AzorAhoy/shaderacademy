# Step-by-Step Explanation of the Particle Shaders

This example contains a [vertex shader](./vert.glsl) that displaces each
input vertex using a deterministic pseudo-random offset, and a
[fragment shader](./frag.glsl) that derives a bright color from the resulting
world-space position.

The shaders do not create a particle system by themselves. A host application
must provide the geometry, transformation matrices, and draw call. In
particular, the point-size setting is meaningful when the geometry is drawn as
points.

## 1. Overview of the pipeline

For each input vertex:

1. The vertex shader hashes the vertex's original position three times to
   produce an X, Y, and Z offset.
2. It adds that offset to the original position and transforms the result into
   world space and clip space.
3. If the host draws points, the rasterizer generates fragments for a small
   square point around each transformed vertex.
4. The fragment shader hashes the interpolated world-space position and uses
   the results to choose red, green, and blue channel values.
5. It writes the resulting opaque color.

The pseudo-random values are calculated from position; there is no time input
or simulation update in these shaders. With unchanged inputs, the pattern is
static.

## 2. Vertex shader

### Step 1: Choose the GLSL version and precision

```glsl
#version 300 es
precision highp float;
```

`#version 300 es` selects GLSL ES 3.00, as used by WebGL 2. `highp` requests
high-precision floating-point calculations. This is relevant to the position
transforms and the sine-based pseudo-random function.

### Step 2: Receive per-vertex inputs

```glsl
in vec3 position;
in vec3 normal;
in vec2 uv;
```

- `position` is the input vertex's local/object-space position. It is also
  the seed used to generate that vertex's displacement.
- `normal` is the vertex's local-space normal.
- `uv` is the vertex's texture coordinate.

The host supplies the active vertex attributes through its geometry and
attribute bindings. Although the vertex shader forwards the transformed normal
and UV, the current fragment shader does not use either of them; a shader
compiler may optimize those unused inputs and varyings away.

### Step 3: Receive transformation matrices

```glsl
uniform mat4 world;
uniform mat4 worldView;
uniform mat4 worldViewProjection;
```

Uniforms have the same value for all vertices in a draw call:

- `world` transforms an object-space position to world space.
- `worldView` is declared but not used in this shader.
- `worldViewProjection` transforms an object-space position to clip space,
  conventionally using projection × view × world in that order.

The host must supply consistent matrices for the same object and camera.
Because the matrices are not calculated here, camera and coordinate-system
conventions depend on the host renderer.

### Step 4: Declare values passed to the fragment shader

```glsl
out vec3 vNormal;
out vec3 vPosition;
out vec2 v_uv;
```

These outputs match the fragment shader's `in` declarations. The graphics
pipeline interpolates varying values across a primitive. For a point, the
varyings come from its single vertex; for triangles or lines, positions can
vary between fragments through interpolation.

Only `vPosition` affects the current fragment shader's output. `vNormal` and
`v_uv` are forwarded but unused.

### Step 5: Generate a pseudo-random number from a 3D seed

```glsl
float random(vec3 seed) {
    return fract(sin(dot(seed, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}
```

This function turns a `vec3` into a floating-point value:

1. `dot(seed, vec3(12.9898, 78.233, 45.164))` multiplies each seed component
   by a different constant and adds the results, producing one scalar.
2. `sin(...)` maps that scalar to a value between `-1` and `1`.
3. Multiplication by `43758.5453` magnifies changes in the sine result.
4. `fract(...)` keeps the fractional part, producing a value in `[0, 1)`.
   In GLSL, `fract(x)` is `x - floor(x)`, so it is nonnegative even when
   `x` is negative.

The constants are hash parameters, not physical quantities. This is a compact
deterministic visual hash, not a statistically guaranteed or cryptographically
secure random-number generator. Identical seeds yield identical results within
the same execution environment. Floating-point precision and sine
implementation can differ across GPUs, so exact results need not match across
devices.

### Step 6: Save the original position

```glsl
vec3 originalPos = position;
```

The shader copies the input position into `originalPos`. All three random
offset components are seeded from this same original position, rather than
from an already-displaced position.

### Step 7: Generate a 3D displacement

```glsl
vec3 randomOffset = vec3(
    random(originalPos + vec3(1.0, 0.0, 0.0)) * 2.0 - 1.0,
    random(originalPos + vec3(0.0, 1.0, 0.0)) * 2.0 - 1.0,
    random(originalPos + vec3(0.0, 0.0, 1.0)) * 2.0 - 1.0
) * 2.0;
```

The three calls use different seed offsets to obtain different X, Y, and Z
values. Adding `(1, 0, 0)`, `(0, 1, 0)`, or `(0, 0, 1)` changes the hash input;
these offsets do not themselves move the particle by one unit.

For each component, the arithmetic maps the hash value as follows:

```text
random(seed)           -> [0, 1)
random(seed) * 2 - 1   -> [-1, 1)
(random(seed) * 2 - 1) * 2 -> [-2, 2)
```

Thus the displacement is nominally up to two local units in either direction
along each axis. These are per-axis bounds: the offset lies in a cube, not
necessarily inside a sphere of radius two. For example, a hash result of
`0.75` becomes `(0.75 * 2 - 1) * 2 = 1.0` for that component.

This seed scheme does not guarantee independent or uniformly distributed
components. Vertices with identical original positions get identical offsets,
even if they have different normals or UVs.

### Step 8: Apply the displacement

```glsl
vec3 newPos = originalPos + randomOffset;
```

The new position is still in object/local space. The offset is added before
the world transform, so object rotation and scale also affect the apparent
direction and size of the displacement in world space.

### Step 9: Set the point size

```glsl
gl_PointSize = 2.0;
```

When the host draws point primitives, `gl_PointSize` requests a point size of
two framebuffer pixels. The implementation's supported point-size range and
rasterization rules determine the final coverage. This is a screen-space
size, not a world-space radius; the shader does not change it based on camera
distance.

If the host draws triangles or lines instead, this assignment does not turn
their vertices into separate point primitives. The host chooses the primitive
type in its draw call.

### Step 10: Compute the world-space position

```glsl
vec4 worldPos = world * vec4(newPos, 1.0);
vPosition = worldPos.xyz;
```

`vec4(newPos, 1.0)` creates a homogeneous position. The `1.0` allows a
conventional affine world matrix to apply translation as well as rotation and
scale. The shader passes the resulting X, Y, and Z components to the fragment
shader.

For the conventional affine world matrix assumed here, `worldPos.w` remains
`1`. The shader does not divide by `w`, so a non-affine world matrix would
require different handling.

### Step 11: Forward the normal and UV

```glsl
vNormal = normalize(mat3(world) * normal);
v_uv = uv;
```

`mat3(world)` extracts the upper-left 3×3 portion of the world matrix.
Multiplying by the normal transforms its direction, and `normalize` makes it
unit length when the transformed vector is nonzero. The UV is passed through
unchanged.

The normal transform is suitable for rotations and uniform scale, but
non-uniform scale or shear generally requires an inverse-transpose normal
matrix. Neither output currently affects the fragment color, so this example
does not perform lighting or texture mapping.

### Step 12: Compute clip-space position

```glsl
gl_Position = worldViewProjection * vec4(newPos, 1.0);
```

`gl_Position` is the required vertex output used for clipping and
rasterization. The displaced local position is transformed by the combined
matrix. After clipping, the pipeline performs the perspective divide and
viewport mapping to determine where the point or other primitive appears.

## 3. Fragment shader

### Step 1: Declare inputs, uniforms, and output

```glsl
in vec3 vNormal;
in vec3 vPosition;
in vec2 v_uv;

uniform vec3 lightPosition;
uniform vec3 lightColor;
uniform vec3 objectColor;
uniform float shininess;

out vec4 fragColor;
```

`vPosition` is the world-space position produced by the vertex shader and is
the only varying used to calculate the current color. `vNormal` and `v_uv`
are declared but unused.

The four lighting/material uniforms are also unused: the current shader does
not calculate diffuse or specular lighting and does not apply `objectColor`.
Unused uniforms and varyings may be removed by the shader compiler, so the
host should not assume they all have active locations.

`fragColor` is the RGBA output for the fragment.

### Step 2: Reuse the pseudo-random hash

The fragment shader defines the same `random(vec3 seed)` formula as the
vertex shader. Here it is applied to world-space positions to generate color
components, not to the original local-space positions used for displacement.

### Step 3: Generate a binary value for each color channel

```glsl
vec3 getParticleColor(vec3 pos) {
    float r = step(0.5, random(pos + vec3(1.0, 0.0, 0.0)));
    float g = step(0.5, random(pos + vec3(0.0, 1.0, 0.0)));
    float b = step(0.5, random(pos + vec3(0.0, 0.0, 1.0)));
    return vec3(r, g, b);
}
```

Each channel hashes the position with a different seed offset. GLSL's
`step(edge, x)` returns `0.0` if `x < edge`, and `1.0` otherwise. Therefore:

- A hash value below `0.5` switches that channel off.
- A hash value at or above `0.5` switches it on.

Each RGB channel is either `0` or `1`, producing eight possible combinations:
black, red, green, blue, cyan, magenta, yellow, and white. Black points can be
hard to see against a dark background. The function does not guarantee that
the eight colors occur equally often.

### Step 4: Choose the color and write it

```glsl
vec3 color = getParticleColor(vPosition);
fragColor = vec4(color, 1.0);
```

The shader passes the fragment's world-space position to `getParticleColor`
and writes the resulting RGB with an alpha of `1.0` (fully opaque).

For a point primitive, the fragments use the point vertex's `vPosition`, so
the point receives one position-derived color. For a triangle or line,
`vPosition` is interpolated across the primitive, and the hash can produce
different colors at different fragments. Changing the world transform changes
the world-space seed and can therefore change colors, even though the
object-space displacement stays the same.

## 4. Practical considerations

- **Static, not animated:** there is no time uniform, velocity, lifetime,
  particle spawning, or movement update. The host must provide any animation
  or evolving particle data.
- **Point appearance:** the fragment shader does not use `gl_PointCoord` or
  discard corners, so point primitives are square rather than circular.
- **Host draw mode:** use a points draw call to see individual point particles.
  Triangle geometry instead connects the displaced vertices into triangles.
- **Stable versus changing colors:** colors depend on world-space position.
  Moving, rotating, or scaling the object changes the seed. Use a stable
  per-particle identifier or object-space seed if colors need to stay attached
  while the object moves.
- **Repeated vertices:** identical local positions receive identical offsets.
  A unique per-particle seed supplied by the host would be needed to distinguish
  them.
- **Visual randomness:** the sine hash is convenient for a demonstration but
  its distribution and cross-device reproducibility are not guaranteed.
