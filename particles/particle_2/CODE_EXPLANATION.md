# Step-by-Step Explanation of the Animated Particle Shaders

This example uses a [vertex shader](./vert.glsl) to move each input vertex from
its original position toward a deterministic pseudo-random target. A
[fragment shader](./frag.glsl) then derives a color from the resulting
world-space position.

The host application must supply the geometry, matrices, time values, and draw
call. These shaders do not create or manage particles by themselves. To render
individual point particles, the host must draw the vertices as point primitives.

## 1. Overview

For each vertex, the shaders and graphics pipeline perform these steps:

1. Use the original local-space position as a seed for a pseudo-random offset.
2. Add the offset to the original position to get a target position.
3. Divide the current time by a maximum time to get an interpolation factor.
4. Interpolate from the original position toward the target.
5. Transform the animated position to world space and clip space.
6. If the host draws points, rasterize a small square point at each position.
7. Hash the world-space position to choose an opaque RGB color.

Unlike the [particle 1 example](../particle_1/CODE_EXPLANATION.md), which
immediately applies the whole offset, this example uses time to interpolate
along the offset.

## 2. Vertex shader: animate each vertex

### Step 1: Select the language version and precision

```glsl
#version 300 es
precision highp float;
```

GLSL ES 3.00 is the shader language version used by WebGL 2. `highp` requests
high-precision floating-point calculations for quantities such as positions,
time, matrix transforms, and the pseudo-random hash.

### Step 2: Receive mesh attributes

```glsl
in vec3 position;
in vec3 normal;
in vec2 uv;
```

These are per-vertex inputs supplied by the host:

- `position` is the original local/object-space position. It is also the seed
  for the particle's target offset.
- `normal` is the local-space vertex normal.
- `uv` is the vertex's 2D texture coordinate.

The shader forwards the transformed normal and UV, but the current fragment
shader does not use them. A compiler may optimize unused attributes and
varyings away.

### Step 3: Receive transformation and animation uniforms

```glsl
uniform mat4 world;
uniform mat4 worldView;
uniform mat4 worldViewProjection;
uniform float u_time;
uniform float u_maxTime;
```

Uniform values are shared by all vertices in the draw call:

- `world` transforms local-space positions to world space.
- `worldView` is declared but not used.
- `worldViewProjection` transforms local-space positions to clip space,
  conventionally using projection × view × world.
- `u_time` is the time used to advance the interpolation.
- `u_maxTime` is the time at which the interpolation factor reaches `1`.

The host must update `u_time` and provide `u_maxTime` in the same units; for
example, both can be measured in seconds. Use a positive, nonzero
`u_maxTime`: the shader divides by it without checking for zero.

### Step 4: Declare values passed to the fragment shader

```glsl
out vec3 vNormal;
out vec3 vPosition;
out vec2 v_uv;
```

These match the fragment shader's input declarations. `vPosition` carries the
animated world-space position. `vNormal` and `v_uv` are forwarded but unused by
the current fragment shader.

Varyings are interpolated across primitives. For a point, the values come from
its single vertex; for triangles or lines, values can vary across the primitive.

### Step 5: Define the pseudo-random hash

```glsl
float random(vec3 seed) {
    return fract(sin(dot(seed, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}
```

This function turns a 3D seed into a scalar:

1. `dot` multiplies each seed component by a constant and adds the results.
2. `sin` maps the result into `[-1, 1]`.
3. Multiplication by `43758.5453` magnifies changes in that sine value.
4. `fract` keeps the fractional part, nominally producing a value in `[0, 1)`.
   In GLSL, `fract(x)` is `x - floor(x)`, including for negative inputs.

The constants are hash parameters, not distances or physical values. The
function is deterministic for the same input within the same execution
environment, but it does not guarantee independent or uniformly distributed
results. Floating-point precision and sine implementations can differ across
GPUs, so exact values are not guaranteed to match between devices.

### Step 6: Save the original position

```glsl
vec3 originalPos = position;
```

The input position is copied to `originalPos`. It serves as both the animation
start and the seed used to choose the target.

### Step 7: Generate a target offset

```glsl
vec3 randomOffset = vec3(
    random(originalPos + vec3(1.0, 0.0, 0.0)) * 2.0 - 1.0,
    random(originalPos + vec3(0.0, 1.0, 0.0)) * 2.0 - 1.0,
    random(originalPos + vec3(0.0, 0.0, 1.0)) * 2.0 - 1.0
) * 2.0;
```

The shader makes three hash calls with different seed offsets for X, Y, and Z.
The seed offsets distinguish the calls; they are not themselves the final
particle displacement.

Each component is remapped as follows:

```text
random(seed)                   -> [0, 1)
random(seed) * 2.0 - 1.0       -> [-1, 1)
(random(seed) * 2.0 - 1.0) * 2 -> [-2, 2)
```

For example, a hash result of `0.75` becomes a local-space offset component of
`1.0`. The three per-axis bounds form a cube around the original position,
not a sphere: the total distance of an offset may exceed two units.

The target is stable while `originalPos` remains unchanged. Vertices with
identical original positions receive the same offset, even when their other
attributes differ.

### Step 8: Compute the target position

```glsl
vec3 targetPos = originalPos + randomOffset;
```

The target is the original local position translated by the generated offset.
The nearby TODO comment describes this intended operation; the active line
already performs it.

### Step 9: Calculate animation progress

```glsl
float progress = u_time / u_maxTime;
```

`progress` expresses the current time as a fraction of `u_maxTime`. For a
positive `u_maxTime`:

| Time | Progress | Intended position |
| --- | --- | --- |
| `0` | `0` | Original position |
| `0.25 * u_maxTime` | `0.25` | One quarter of the way to the target |
| `0.5 * u_maxTime` | `0.5` | Halfway to the target |
| `u_maxTime` | `1` | Target position |

This division is not clamped. A time greater than `u_maxTime` gives a factor
greater than `1`, and a negative time gives a negative factor. Division by
zero has no useful defined animation behavior, so the host must avoid it.

### Step 10: Interpolate to the animated position

```glsl
vec3 newPos = mix(originalPos, targetPos, progress);
```

For a scalar factor, `mix(a, b, t)` calculates
`a * (1.0 - t) + b * t`. Since `targetPos` is `originalPos + randomOffset`,
this is equivalent to:

```text
newPos = originalPos + randomOffset * progress
```

At `progress = 0`, the vertex is at the original position; at `0.5`, it is
halfway along the offset; and at `1`, it reaches the target. If progress is
`1.5`, it continues halfway beyond the target. At `-0.5`, it moves half an
offset in the opposite direction. `mix` does not automatically clamp its
factor.

For example, if the original X coordinate is `1`, its target is `3`, and
progress is `0.25`, the animated X is `1 + (3 - 1) * 0.25 = 1.5`.

With `u_time` increasing linearly, `u_maxTime` fixed, and the original
position unchanged, each vertex travels along a straight line at a constant
local-space velocity of `randomOffset / u_maxTime`. All vertices share the
same progress, but their different offsets produce different velocities.
The host can clamp time to stop at the target, reset time to restart, or
provide a different time curve; none of those behaviors is implemented here.

### Step 11: Set the point size

```glsl
gl_PointSize = 2.0;
```

For point primitives, this requests a point size of two framebuffer pixels.
Actual point coverage is subject to the implementation's supported point-size
range and rasterization rules. This is a screen-space size, not a world-space
radius, and this shader does not scale it with distance.

The host's draw mode determines whether the vertices are rendered as points,
lines, or triangles; setting `gl_PointSize` alone does not choose that mode.

### Step 12: Compute world-space position and forward attributes

```glsl
vec4 worldPos = world * vec4(newPos, 1.0);
vPosition = worldPos.xyz;
vNormal = normalize(mat3(world) * normal);
v_uv = uv;
```

- `vec4(newPos, 1.0)` makes a homogeneous position, allowing a conventional
  affine `world` matrix to apply translation as well as rotation and scale.
- `vPosition` receives the animated world-space position, which the fragment
  shader uses as its color seed. This assumes an affine world transform;
  the code takes `xyz` directly without dividing by `w`.
- `mat3(world) * normal` transforms the normal's direction, and `normalize`
  makes it unit length when the result is nonzero.
- `v_uv` receives the original UV unchanged.

For non-uniform scale or shear, a normal generally needs an inverse-transpose
normal matrix rather than `mat3(world)`. In this particular shader pair, the
fragment shader does not use the normal or UV, so neither affects the color.
The offset is applied in local space before `world`, so object rotation and
scale affect the resulting world-space trajectory.

### Step 13: Compute clip-space position

```glsl
gl_Position = worldViewProjection * vec4(newPos, 1.0);
```

`gl_Position` is the required position output used by clipping and
rasterization. The combined matrix transforms the animated local position into
clip space. The graphics pipeline then performs the perspective divide and
viewport mapping to determine the on-screen position.

## 3. Fragment shader: choose a color

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

The fragment shader uses `vPosition`, the animated world-space position, to
choose color. `vNormal`, `v_uv`, and all four lighting/material uniforms are
declared but unused. Consequently, this shader does not currently calculate
lighting or sample a texture. Unused shader inputs and uniforms may be
optimized away and need not have active locations.

### Step 2: Hash the world-space position

The fragment shader defines the same `random(vec3 seed)` formula as the
vertex shader. However, its seed is the animated **world-space** position,
whereas the vertex displacement was seeded by the original **local-space**
position. These are different purposes and coordinate spaces.

### Step 3: Choose each RGB channel

```glsl
vec3 getParticleColor(vec3 pos) {
    float r = step(0.5, random(pos + vec3(1.0, 0.0, 0.0)));
    float g = step(0.5, random(pos + vec3(0.0, 1.0, 0.0)));
    float b = step(0.5, random(pos + vec3(0.0, 0.0, 1.0)));
    return vec3(r, g, b);
}
```

Each channel uses a different seed offset. GLSL's `step(edge, x)` returns
`0.0` if `x < edge` and `1.0` otherwise, so each hash is thresholded at `0.5`:
below the threshold the channel is off; at or above it the channel is on.

Each channel is binary, giving eight possible colors: black, red, green, blue,
cyan, magenta, yellow, and white. Black points can be difficult to see against
a dark background, and this hash does not guarantee equal frequencies for the
eight colors.

### Step 4: Write the opaque color

```glsl
vec3 color = getParticleColor(vPosition);
fragColor = vec4(color, 1.0);
```

The calculated RGB color is written with alpha `1.0`, making it fully opaque.
For a point primitive, all fragments use the point vertex's `vPosition`, so a
point gets one position-derived color. For a triangle or line, interpolation
can give different fragments different position seeds.

Because `vPosition` changes as the vertex moves, its hash can cross the
thresholds and change color during animation. Moving the object through its
world transform can also change the color. This is not a stable per-particle
color.

## 4. Practical considerations

- **Time is host-controlled:** update `u_time` and supply a positive, nonzero
  `u_maxTime`. The shader does not advance, clamp, reset, or loop time itself.
- **Extrapolation is intentional code behavior:** after `u_time` exceeds
  `u_maxTime`, vertices continue beyond their targets unless the host limits
  time or the shader is changed to clamp progress.
- **Colors can flicker or change:** they are hashed from the current
  world-space position, not a stable particle ID. A separate stable seed would
  be needed to keep a particle's color fixed during motion.
- **Point shape:** without a `gl_PointCoord` test or discarded corners, point
  primitives are square rather than circular.
- **Primitive type matters:** draw points for separate particles. Drawing
  triangles or lines connects the displaced vertices instead.
- **Duplicate positions share a target:** unique per-particle seeds would be
  needed to distinguish vertices with identical original positions.
- **No full particle simulation:** there is no velocity state, gravity,
  lifetime, spawning, or collision handling; the motion is a position
  interpolation calculated independently for each vertex.
