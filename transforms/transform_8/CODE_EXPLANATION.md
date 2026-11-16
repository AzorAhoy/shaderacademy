# Transform 8: Tapering Along Z

Explore the effect visually in the [transformation explorer](../transform-demo.html); select lesson 8.

The [vertex shader](./vert.glsl) changes a vertex's local Y coordinate according to its local Z coordinate. The [fragment shader](./frag.glsl) uses simple diffuse lighting. The host provides the geometry, transforms, and lighting uniforms.

## What is tapering?

**Tapering** gradually changes the size of a shape's cross-section as you move along an axis. Imagine narrowing one end of a wooden beam or widening the base of a vase. Unlike uniform scaling, which applies the same factor everywhere, a taper uses a different scale at different positions along the chosen axis.

In this lesson:

- **Taper direction:** local Z. The vertex's Z coordinate determines how much scaling is applied.
- **Scaled direction:** local Y. The shader changes Y, but leaves X and Z unchanged.
- **Center of scaling:** local `y = 0`. Points above and below that line move toward or away from it.

For example, consider a cube that spans `-1` to `1` on each local axis. Looking along X gives this schematic YZ side view:

```text
             original                    tapered
      +----------------+                           /
      |                |                    _____/
      |                |              _____/
      +----------------+--> z       .------------------> z   y = 0
      |                |              \_____
      |                |                    \_____
      +----------------+                           \
     z=-1            z=1           z=-1            z=1
```

The drawing is schematic, not to scale: the left end is almost flat and the right end is nearly twice the original height. At any fixed Z, the X dimension is unchanged; only the Y dimension of that X-Y cross-section changes. The world and camera transforms can make the result appear in a different orientation on screen.

## How the taper factor works

The shader's formula is:

```text
factor(z) = 1 + 0.95 * z
x' = x
y' = y * factor(z)
z' = z
```

For every vertex:

1. Read its **original local Z**.
2. Multiply Z by `0.95`; this controls how quickly the scale changes along Z.
3. Add `1` so the factor is exactly `1` at `z = 0`.
4. Multiply the original Y by that factor. X and Z are not changed.

For an original cross-section extending from `y = -1` to `y = 1`, the result is:

| Local Z | Factor | Transformed Y range | Cross-section height |
| --- | --- | --- | --- |
| `-1` | `0.05` | `-0.05` to `0.05` | `0.10` |
| `-0.5` | `0.525` | `-0.525` to `0.525` | `1.05` |
| `0` | `1.0` | `-1` to `1` | `2.0` |
| `0.5` | `1.475` | `-1.475` to `1.475` | `2.95` |
| `1` | `1.95` | `-1.95` to `1.95` | `3.90` |

These are **local-space** numbers before the `world` matrix. The cross-section height assumes the original Y range shown above; the shader does not know or enforce a particular mesh size.

### Worked examples

At `(0, 0.8, -1)`:

1. The factor is `1 + 0.95 * (-1) = 0.05`.
2. The new Y is `0.8 * 0.05 = 0.04`.
3. The result is `(0, 0.04, -1)`, much closer to the center line.

At `(0, -0.8, 1)`:

1. The factor is `1 + 0.95 * 1 = 1.95`.
2. The new Y is `-0.8 * 1.95 = -1.56`.
3. The result is `(0, -1.56, 1)`, farther below the center line.

Points at `y = 0` remain there regardless of Z. If a mesh is not centered on `y = 0`, it scales about that line rather than automatically tapering around its own center.

### Changing the taper

In the more general expression `factor(z) = 1 + k * z`, the coefficient `k` controls the slope:

- `k = 0` gives factor `1` everywhere: no taper.
- Positive `k` makes the factor increase as Z increases.
- Negative `k` makes the factor decrease as Z increases.
- A larger magnitude changes the factor more rapidly over the same Z distance.

The result depends on the mesh's local Z range. The fixed `0.95` value that produces a strong taper for a cube spanning `[-1, 1]` can collapse or invert part of a longer mesh. The source does not clamp the factor or normalize the mesh coordinates.

For this shader, `1 + 0.95 * z = 0` at `z = -1 / 0.95`, approximately `-1.0526`. There, all Y values collapse to zero. Below that Z, the factor is negative and Y changes sign. A zero factor creates degenerate geometry, and a negative factor reflects the cross-section, which can affect face orientation and culling. To avoid those effects, choose parameters that keep the factor positive over the actual mesh range.

### Taper around a different center

The current formula scales around `y = 0`. Conceptually, a different center `centerY` can be used by subtracting it before scaling, then adding it back:

```glsl
float factor = 1.0 + 0.95 * position.z;
float newY = centerY + (position.y - centerY) * factor;
```

For example, setting `centerY` to the bottom of a beam keeps points on that line fixed while the opposite side moves. This is an illustration of the idea, not code present in the lesson; a real implementation also needs to account for the resulting surface normals.

## Try it in the explorer

Open the [transformation explorer](../transform-demo.html) and select **8. Taper along Z**. Compare the gray original cube with the cyan tapered cube:

1. Follow the colored Z axis to see which direction controls the factor.
2. Rotate the view to compare the narrow and wide ends.
3. Read the marked point's before-and-after coordinates. It lies at `z = 0.6`, where the factor is `1.57`, so its Y changes from `0.35` to approximately `0.55`.
4. The time slider has no effect on this lesson: its taper factor is fixed and its shader has no `u_time` input.

The explorer uses a subdivided cube and illustrates the position formula; it does not render this GLSL shader or its lighting.

## Vertex shader

### 1. Declare the shader interface

`#version 300 es` selects GLSL ES 3.00 and `highp` requests high-precision floats. `position` and `normal` are local-space vertex attributes; `uv` is a texture coordinate. `world` maps local to world space, and `worldViewProjection` normally combines projection * view * world. `worldView` is unused.

`vPosition`, `vNormal`, and `v_uv` are sent to the fragment stage. UV is unused there.

### 2. Calculate the tapered position

```glsl
float taperFactor = 0.95;
vec3 taperedPosition = position;
taperedPosition.y *= (1.0 + taperFactor * position.z);
```

The shader copies the original point and changes only Y:

```text
x' = x
y' = y * (1 + 0.95 * z)
z' = z
```

At `z = 0`, Y is unchanged. At `z = 1`, Y is multiplied by `1.95`; at `z = -1`, it is multiplied by `0.05`. For example, `(0, 2, 1)` becomes `(0, 3.9, 1)`. This is a taper controlled by Z, not uniform scaling along the entire object.

The factor becomes zero at approximately `z = -1.0526`, collapsing Y there, and becomes negative for smaller Z, flipping the Y coordinate. The result therefore depends on the mesh's local Z range. The `TODO` comment is an exercise prompt; the calculation is present.

### 3. Prepare the varyings and clip position

```glsl
vec4 worldPos = world * vec4(position, 1.0);
vPosition = worldPos.xyz;
vNormal = normalize(mat3(world) * normal);
v_uv = uv;
gl_Position = worldViewProjection * vec4(taperedPosition, 1.0);
```

The rendered position is tapered before world/view/projection, but `vPosition` and `vNormal` use the original geometry. The lighting point and surface orientation can therefore be wrong for the visible shape.

Correcting the position requires using `taperedPosition` for `worldPos`. Correct normals require accounting for the taper's position-dependent deformation, not merely applying the unchanged world matrix. `mat3(world)` itself is appropriate for rotation and uniform world scale; non-uniform scaling or shear generally needs an inverse-transpose normal matrix.

The deformation is evaluated at vertices. Rasterization draws triangles between the transformed vertices, so a coarse mesh approximates the intended continuous taper.

### Why tapering changes normals

Imagine the top of a box, initially at `y = 1` with local normal `(0, 1, 0)`. After the continuous taper, its height is `y' = 1 + 0.95 * z`: the top now slopes upward as Z increases. A normal pointing straight up is no longer perpendicular to that slope. At `z = 0`, a perpendicular local-space direction is proportional to `(0, 1, -0.95)`; normalize it before lighting.

More generally, for `a = 1 + k*z`, the local deformation maps `(x, y, z)` to `(x, a*y, z)`. Where `a` is nonzero, applying the inverse transpose of its local Jacobian transforms an input normal `(nx, ny, nz)` to a direction proportional to:

```text
(nx, ny / a, nz - k * y * ny / a)
```

Normalize that direction, then apply the appropriate world-space normal transform. This describes the continuous deformation; the lesson shader does **not** implement it. At `a = 0`, the deformation is singular and this inverse does not exist. The actual normals appropriate for a discretely triangulated mesh can also differ from the continuous surface.

## Fragment shader

### 1. Receive the surface and light

The shader uses interpolated `vPosition` and `vNormal`. The host supplies a world-space `lightPosition`, an RGB `lightColor`, and `objectColor`. `v_uv` is declared but unused.

### 2. Compute and write diffuse light

```glsl
vec3 normal = normalize(vNormal);
vec3 lightDir = normalize(lightPosition - vPosition);
float diff = max(dot(normal, lightDir), 0.0);
vec3 diffuse = diff * lightColor;
vec3 result = diffuse * objectColor;
fragColor = vec4(result, 1.0);
```

The normal and direction to the light are normalized, their dot product is clamped at zero, and the factor multiplies light and object colors. The result is opaque and has no ambient, specular, or attenuation term. Since the varyings do not reflect the taper, lighting can appear detached or incorrect.
