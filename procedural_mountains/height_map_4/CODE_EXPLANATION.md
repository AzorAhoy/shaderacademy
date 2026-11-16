# Height Map 4: A Grid of Pyramids

Imagine a square sheet divided into smaller squares. Instead of making one
point in the middle of the whole sheet, this lesson makes a point in the
middle of **each** small square.

- The [vertex shader](./vert.glsl) moves the mesh's points to create the
  repeated shape.
- The [fragment shader](./frag.glsl) colors the surface using a light.

The shader calculates the height from UV coordinates; it does not read a
height-map image. The host supplies the mesh, UVs, transforms, and lighting.
Those are not included in this folder, so the exact appearance depends on
the host.

## A few words to know

- **Vertex:** a point in a 3D mesh. Triangles connect vertices to make a
  surface.
- **UV:** two numbers, `u` and `v`, that label a point on a 2D map. They
  are separate from the point's 3D position.
- **Normal:** an arrow that tells the lighting code which way a surface
  faces.
- **Local space:** the object's own coordinate system. **World space** is
  the shared coordinate system used to place the object and the light.
- **Shader:** a small program that runs on the GPU. A vertex shader works on
  vertices; a fragment shader works on fragments that can contribute to
  pixels.

## The big idea

The shader divides the usual `[0, 1]` UV square into a **4 by 4 grid**.
Within each cell, it moves the center `1.5` units along negative local Z
and leaves the cell boundaries unchanged.

```text
UV map: each * marks a cell center

v = 1  +-----+-----+-----+-----+
       |  *  |  *  |  *  |  *  |
       +-----+-----+-----+-----+
       |  *  |  *  |  *  |  *  |
       +-----+-----+-----+-----+
       |  *  |  *  |  *  |  *  |
       +-----+-----+-----+-----+
       |  *  |  *  |  *  |  *  |
v = 0  +-----+-----+-----+-----+
     u = 0                    u = 1
```

For a flat local XY square with evenly mapped UVs and suitable triangles,
the ideal result is 16 square pyramids. The actual mesh needs enough
vertices in the right places; the diagram is the height function, not a
guarantee about the mesh.

**Negative local Z is not automatically down.** If the host orients local
`-Z` toward world up, the points rise. The shader does not tell us how the
host orients the object.

## How the two shaders work together

1. The host gives the vertex shader a position, normal, and UV for each
   vertex, along with transformation matrices.
2. The vertex shader finds where the UV lies inside one grid cell.
3. It uses that cell coordinate to calculate a height and moves the vertex
   along local Z.
4. It sends the moved position to the camera and passes information for
   lighting to the next stage.
5. The GPU interpolates the outputs across each triangle.
6. The fragment shader uses the interpolated position and normal to calculate
   diffuse lighting and output a color.

## Vertex shader, step by step

### 1. Receive the inputs

```glsl
#version 300 es
precision highp float;

in vec3 position;
in vec3 normal;
in vec2 uv;

uniform mat4 world;
uniform mat4 worldView;
uniform mat4 worldViewProjection;

out vec3 vNormal;
out vec3 vPosition;
out vec2 v_uv;
```

The first two lines select GLSL ES 3.00 and request high precision for
floating-point numbers.

- `in` values come from the mesh: local `position`, local `normal`, and `uv`.
- `uniform` values come from the host and are shared across the draw.
  `world` places the object in world space; `worldViewProjection` prepares
  positions for the camera.
- `out` values are sent toward the fragment shader.

`vec2` holds two numbers, `vec3` holds three, and `mat4` is a 4-by-4
transformation matrix. `worldView` is declared but not used.

### 2. Copy the position and set the controls

```glsl
vec3 modifiedPosition = position;
float gridCount = 4.0;
float pyramidHeight = 1.5;
```

`modifiedPosition` starts as a copy of the input position. The shader will
change its Z component.

`gridCount` controls how many times the pattern repeats along **each** UV
axis. With `4.0`, the usual square contains four cells across and four down:
`4 * 4 = 16` cells. `pyramidHeight` sets the magnitude of the center
displacement to `1.5` local units. Both values are hard-coded, not uniforms.

### 3. Find the position inside a cell

```glsl
vec2 cellUV = fract(uv * gridCount);
```

Read this from inside out:

1. Multiply both UV components by `4`. For example, `(0.375, 0.125)`
   becomes `(1.5, 0.5)`.
2. `fract` keeps the fractional part of each component. The result is
   `(0.5, 0.5)`: the center of that cell.

`fract(x)` is `x - floor(x)`. It repeats as the UV moves from one cell to
the next. For example, `fract(0.5)` and `fract(1.5)` are both `0.5`.
It also works for negative coordinates: `fract(-0.5)` is `0.5`.

| Original UV | `uv * 4` | `cellUV` | Where in a cell? |
| --- | --- | --- | --- |
| `(0, 0)` | `(0, 0)` | `(0, 0)` | Corner |
| `(0.125, 0.125)` | `(0.5, 0.5)` | `(0.5, 0.5)` | Center of the first cell |
| `(0.375, 0.125)` | `(1.5, 0.5)` | `(0.5, 0.5)` | Center of the next cell |
| `(0.25, 0.125)` | `(1, 0.5)` | `(0, 0.5)` | Cell boundary |
| `(1, 1)` | `(4, 4)` | `(0, 0)` | Outer boundary |

At a grid boundary, the fractional coordinate wraps from almost `1` back to
`0`. The height formula below approaches `0` from either side, so the
ideal height is continuous at the boundary, even though `cellUV` wraps.
UVs outside `[0, 1]` are not clamped: the pattern continues repeating.

### 4. Measure distance from the cell center

```glsl
vec2 distFromCenter = abs(cellUV - 0.5);
```

Each cell's center is `(0.5, 0.5)` in `cellUV` coordinates.

1. Subtract `(0.5, 0.5)` to find the horizontal and vertical offsets.
2. `abs` removes minus signs. For example, `abs(-0.25)` is `0.25`.

| `cellUV` | After subtracting `0.5` | `distFromCenter` |
| --- | --- | --- |
| `(0.5, 0.5)` | `(0, 0)` | `(0, 0)` |
| `(0.25, 0.5)` | `(-0.25, 0)` | `(0.25, 0)` |
| `(0, 0.5)` | `(-0.5, 0)` | `(0.5, 0)` |

### 5. Turn the distance into a pyramid height

```glsl
float height = -1.0 + max(distFromCenter.x, distFromCenter.y) * 2.0;
```

1. `max` picks the larger of the two distances.
2. Multiply it by `2`.
3. Add `-1`.

For example, if `distFromCenter` is `(0.25, 0)`, the calculation is
`-1 + max(0.25, 0) * 2 = -1 + 0.5 = -0.5`.

Using the larger component is called **Chebyshev distance**. It makes
equal-height outlines square within each cell, rather than circular.
For example, `(0.75, 0.5)` and `(0.75, 0.75)` are both `0.25` away from
the cell center by this rule, so they have the same height.

| Position in cell | Largest distance | `height` |
| --- | --- | --- |
| Center `(0.5, 0.5)` | `0` | `-1` |
| Halfway to an edge `(0.25, 0.5)` | `0.25` | `-0.5` |
| Edge `(0, 0.5)` | `0.5` | `0` |
| Corner `(0, 0)` | `0.5` | `0` |

### 6. Move the vertex

```glsl
modifiedPosition.z += height * pyramidHeight;
```

The shader multiplies `height` by `1.5` and **adds** the result to the
original local Z. It does not change X or Y.

| Position in cell | `height` | Change to local Z |
| --- | --- | --- |
| Center | `-1` | `-1.5` |
| Halfway to an edge | `-0.5` | `-0.75` |
| Edge or corner | `0` | `0` |

For a complete example, take position `(2, 1, 0.5)` and UV
`(0.375, 0.125)`:

1. `uv * 4` is `(1.5, 0.5)`, so `cellUV` is `(0.5, 0.5)`.
2. The distance from the cell center is `(0, 0)`, so `height` is `-1`.
3. The Z offset is `-1 * 1.5 = -1.5`.
4. The new Z is `0.5 + (-1.5) = -1`.
5. The resulting local position is `(2, 1, -1)`.

The source still has a `TODO` comment, but the following lines implement the
displacement. A negative `pyramidHeight` would reverse its direction; `0`
would remove it.

### 7. Send the moved position to the camera and lighting

```glsl
vec4 worldPos = world * vec4(modifiedPosition, 1.0);

vPosition = worldPos.xyz;
vNormal = normalize(mat3(world) * normal);
v_uv = uv;

gl_Position = worldViewProjection * vec4(modifiedPosition, 1.0);
```

- `vec4(modifiedPosition, 1.0)` adds a fourth component so the matrix can
  transform the point, including translation.
- `worldPos` is the moved position in world space. `vPosition` passes its
  three position components to the fragment shader.
- `vNormal` is the original normal transformed by `world` and normalized
  to length one. It does **not** account for the new slopes; see the
  limitations below.
- `v_uv` passes the original UV through, although the fragment shader does
  not use it.
- `gl_Position` is the same moved position transformed into clip space for
  the camera and drawing.

The host must supply matching matrices, normally
`worldViewProjection = projection * view * world`. The use of
`worldPos.xyz` assumes an affine `world` transform.

## Fragment shader, step by step

### 1. Receive the lighting information

```glsl
in vec3 vNormal;
in vec3 vPosition;
in vec2 v_uv;

uniform vec3 lightPosition;
uniform vec3 lightColor;
uniform vec3 objectColor;

out vec4 fragColor;
```

The GPU interpolates the vertex outputs across each triangle. The fragment
shader uses `vNormal` and `vPosition`, plus the host-provided light and
object colors. `lightPosition` and `vPosition` must both be in world space.
`v_uv` is declared but not used.

### 2. Make an arrow toward the light

```glsl
vec3 normal = normalize(vNormal);
vec3 lightDir = normalize(lightPosition - vPosition);
```

The interpolated normal may no longer have length one, so the shader
normalizes it again. Subtracting the surface position from the light
position creates an arrow pointing **toward** the light; normalizing it
keeps its direction and makes its length one.

A zero-length normal, or a light exactly at the fragment position, cannot
be normalized reliably.

### 3. Work out how much light reaches the surface

```glsl
float diff = max(dot(normal, lightDir), 0.0);
vec3 diffuse = diff * lightColor;
```

`dot` compares the two unit arrows:

- `1` means they point the same way: the light hits directly.
- `0` means they are at right angles: there is no diffuse light.
- A negative value means the surface normal points away from the light.

`max(..., 0.0)` changes negative results to zero. The shader then multiplies
the light color by the resulting brightness.

### 4. Apply the object color

```glsl
vec3 result = diffuse * objectColor;
fragColor = vec4(result, 1.0);
```

The RGB components are multiplied one by one. For example, if `diff` is
`0.8`, `lightColor` is `(1, 1, 1)`, and `objectColor` is `(0.5, 0.25, 1)`,
the result is `(0.4, 0.2, 0.8)`. The shader outputs alpha `1`; the final
pixel also depends on the renderer's settings.

This shader has no ambient light, specular highlight, shadow calculation, or
distance attenuation. A surface facing away from the light can be black.

## Important limitations

### The mesh needs enough vertices

The height is calculated **at vertices**, not at every point on a triangle.
The GPU joins the moved vertices with straight triangles.

For example, if every UV vertex lies on a grid boundary such as `0`, `0.25`,
`0.5`, `0.75`, or `1` on both axes, each sampled height is zero. Even
though the formula describes 16 pyramids, that mesh will not show them.

For the ideal grid on a flat local XY square, the mesh needs vertices at the
cell centers and boundaries, with triangles aligned to the four sides of
each pyramid. A generic subdivided mesh may only approximate the shape.
Different UV layouts, existing Z positions, and seams can also change the
result.

### The normals do not follow the new slopes

The shader transforms the **original** mesh normals instead of recomputing
them for the displaced surface. The lighting can therefore fail to show the
pyramid sides correctly.

For more accurate lighting, first obtain normals for the displaced surface.
For a non-uniformly scaled or sheared world transform, those normals also
need the inverse transpose of the world's linear matrix, assuming it is
invertible. Points at sharp edges do not have one unique face normal; the
chosen normals determine whether the sides look sharp or smooth.

## Try it

1. Change `gridCount` to `2.0` and compare the resulting `2 by 2` pattern.
   The mesh must have suitable vertices for the new cells too.
2. Change `pyramidHeight` to `0`, `1.5`, and `3.0` to compare displacement.
3. Try a negative `pyramidHeight` to reverse the local Z direction.
4. Compare a boundary-only grid with one that includes cell centers.
5. Move the light and observe the effect of using the original normals.

For the single-pyramid version, see
[Height Map 3](../height_map_3/CODE_EXPLANATION.md).