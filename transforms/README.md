# Understanding 3D Transformations

Transformations move, resize, rotate, or deform geometry. In these lessons, a vertex shader changes each mesh vertex before the graphics pipeline projects and rasterizes it. A fragment shader then calculates the visible color.

This guide explains the underlying ideas and how they appear in the ten examples. Each lesson also has its own detailed shader walkthrough in the learning path below.

Open the [interactive transformation explorer](./transform-demo.html) to compare the original cube with each transformed shape, change the view, and explore animated effects. The visualization illustrates the local position formulas; it is not a GLSL renderer.

## 1. What happens to a vertex?

A typical path through these examples is:

```text
local mesh position
        |
        | optional local scale, rotation, or deformation
        v
transformed local position
        |
        | world matrix
        v
world-space position ---------------------> lighting
        |
        | view matrix
        v
view-space position
        |
        | projection matrix
        v
clip-space position (gl_Position)
        |
        | clipping, then divide by w
        v
normalized device coordinates
        |
        | viewport mapping and rasterization
        v
screen fragments -------------------------> fragment shader
```

The **host application** supplies the geometry, matrices, lighting values, and draw calls. These GLSL files are lessons, not a complete renderer.

### Coordinate spaces

- **Local or object space:** coordinates relative to the mesh's own origin and axes. The shader's `position` and `normal` inputs begin here.
- **World space:** coordinates shared by objects and lights in the scene. The `world` matrix maps local points into this space.
- **View space:** coordinates relative to the camera. The view matrix transforms world space into view space.
- **Clip space:** homogeneous coordinates produced by the projection transform and written to `gl_Position`.
- **Normalized device coordinates (NDC):** obtained by dividing clip-space `xyz` by `w`, after clipping. The viewport then maps them to screen coordinates.

The host chooses the camera and projection. Axis direction on screen depends on that camera; Y-up alone does not determine the camera's handedness or which way it faces. See [3D axes and UV coordinate conventions](../COORDINATE_CONVENTIONS.md) for more context.

## 2. Homogeneous coordinates and matrices

The shaders often start with:

```glsl
vec4 localPoint = vec4(position, 1.0);
```

The fourth component, `w`, allows a 4-by-4 matrix to express translation as well as scale and rotation. For an affine transform, a point has `w = 1`, so translation affects it. A direction has `w = 0`, so translation does not affect it.

For example, the following conceptual translation moves a point by `(tx, ty, tz)`:

```text
             | 1  0  0  tx |   | x |   | x + tx |
T * point =  | 0  1  0  ty | * | y | = | y + ty |
             | 0  0  1  tz |   | z |   | z + tz |
             | 0  0  0   1 |   | 1 |   |   1    |
```

These are mathematical **rows** for readability. GLSL's `mat4(...)` scalar constructor fills a matrix by **columns**. The transform lessons use matrices multiplied by column vectors, such as `matrix * vec4(position, 1.0)`.

The project lessons concentrate on scale, rotation, and deformation; their world matrix can also include translation, but the host's actual matrix values are not specified here.

## 3. Scale

Scaling multiplies coordinates along one or more axes. A uniform scale uses the same factor on x, y, and z:

```glsl
mat4 scale = mat4(
    2.0, 0.0, 0.0, 0.0,
    0.0, 2.0, 0.0, 0.0,
    0.0, 0.0, 2.0, 0.0,
    0.0, 0.0, 0.0, 1.0
);
vec4 scaled = scale * vec4(position, 1.0);
```

Step by step:

1. The diagonal multiplies the local x, y, and z coordinates by 2.
2. The bottom-right `1` preserves the point's homogeneous `w`.
3. `(1, -0.5, 0.25)` becomes `(2, -1, 0.5)`.
4. The later world transform places the scaled local result in the scene.

A factor greater than 1 enlarges distances from the local origin; a positive factor between 0 and 1 reduces them. A zero factor collapses an axis. A negative factor reflects that axis and can change face winding and culling behavior.

- [Transform 1](./transform_1/CODE_EXPLANATION.md) uses a fixed scale of 2.
- [Transform 5](./transform_5/CODE_EXPLANATION.md) uses 0.5.
- [Transform 6](./transform_6/CODE_EXPLANATION.md) animates the uniform scale.

### Animated scale

Transform 6 uses:

```glsl
float s = 1.0 + 0.5 * sin(u_time);
```

`sin` varies between -1 and 1, so `s` varies between 0.5 and 1.5. At `u_time = 0` it is 1; at `pi/2` it is 1.5; at `3*pi/2` it is 0.5. The cycle lasts `2*pi` units of the host-provided time. If time is measured in seconds, that is approximately 6.28 seconds. The host must update `u_time` for the mesh to animate.

## 4. Rotation

A rotation turns a point around an axis. The angle supplied to GLSL trigonometric functions is in **radians**:

| Degrees | Radians |
| --- | --- |
| 45 | `pi / 4` |
| 90 | `pi / 2` |
| 135 | `3 * pi / 4` |
| 360 | `2 * pi` |

### Y-axis rotation in these lessons

[Transform 2](./transform_2/CODE_EXPLANATION.md) and [transform 3](./transform_3/CODE_EXPLANATION.md) use the following matrix form, where `c = cos(angle)` and `s = sin(angle)`:

```glsl
mat4 rotY = mat4(
     c, 0.0,   s, 0.0,
   0.0, 1.0, 0.0, 0.0,
    -s, 0.0,   c, 0.0,
   0.0, 0.0, 0.0, 1.0
);
```

GLSL fills the constructor **by columns**, so its mathematical rows and multiplication by a position are:

```text
|  c  0  -s |   | x |
|  0  1   0 | * | y |
|  s  0   c |   | z |
```

```text
x' = c*x - s*z
y' = y
z' = s*x + c*z
```

For example, at a positive 90-degree angle, `c = 0` and `s = 1`, so local `(1, 0, 0)` becomes approximately `(0, 0, 1)` and `(0, 0, 1)` becomes approximately `(-1, 0, 0)`. The Y coordinate and distance from the Y axis remain unchanged.

In a conventional right-handed XYZ basis, this matrix corresponds to an **active right-handed Y rotation by `-angle`**, not `+angle`. This describes the matrix's algebraic sign; the apparent screen direction still depends on the camera. The [transformation explorer](./transform-demo.html) uses the same formulas.

### X-axis rotation in these lessons

[Transform 4](./transform_4/CODE_EXPLANATION.md) and [transform 7](./transform_7/CODE_EXPLANATION.md) use this X-axis matrix:

```glsl
mat4 rotX = mat4(
   1.0, 0.0, 0.0, 0.0,
   0.0,   c,  -s, 0.0,
   0.0,   s,   c, 0.0,
   0.0, 0.0, 0.0, 1.0
);
```

Again, constructor values are columns. Its mathematical rows and the resulting coordinates are:

```text
| 1   0  0 |   | x |
| 0   c  s | * | y |
| 0  -s  c |   | z |
```

```text
x' = x
y' = c*y + s*z
z' = -s*y + c*z
```

At positive 90 degrees, `(0, 1, 0)` becomes approximately `(0, 0, -1)` and `(0, 0, 1)` becomes approximately `(0, 1, 0)`. X and the distance from the X axis remain unchanged. In a conventional right-handed XYZ basis, this is likewise an active right-handed X rotation by `-angle`.

### Z-axis rotation

A Z-axis rotation changes X and Y while leaving Z unchanged. The current transform lessons do not include a separate Z-rotation shader, but the same matrix pattern can be used:

```glsl
float c = cos(angle);
float s = sin(angle);
mat4 rotZ = mat4(
     c,  -s, 0.0, 0.0,
     s,   c, 0.0, 0.0,
   0.0, 0.0, 1.0, 0.0,
   0.0, 0.0, 0.0, 1.0
);
vec4 rotated = rotZ * vec4(position, 1.0);
```

GLSL fills the constructor by columns, so the mathematical rows and resulting coordinates are:

```text
|  c  s  0 |   | x |     x' = c*x + s*y
| -s  c  0 | * | y |  =  y' = -s*x + c*y
|  0  0  1 |   | z |     z' = z
```

At a positive 90-degree angle, `(1, 0, 0)` becomes approximately `(0, -1, 0)`, and `(0, 1, 0)` becomes approximately `(1, 0, 0)`. The distance from the Z axis, `sqrt(x*x + y*y)`, is preserved. Like the X and Y examples above, this is an active right-handed rotation by `-angle` in a conventional right-handed XYZ basis; negate the angle to obtain the conventional positive right-handed rotation.

The rotation is around the local origin. To use it in a lit shader, rotate the local normal consistently as well as the position, then apply the appropriate world-space normal transform.

### Fixed versus animated rotation

- [Transform 3](./transform_3/CODE_EXPLANATION.md) uses the fixed angle `pi / 4`, or 45 degrees.
- [Transforms 2](./transform_2/CODE_EXPLANATION.md) and [4](./transform_4/CODE_EXPLANATION.md) use `u_time * pi / 4`. If time is in seconds, the angle grows by 45 degrees per second and completes a turn every 8 seconds.
- [Transform 7](./transform_7/CODE_EXPLANATION.md) uses a fixed 135-degree X rotation together with scale.

## 5. Combining transforms and choosing a pivot

Matrix multiplication order matters. For column vectors:

```text
worldPoint = translation * rotation * scale * localPoint
```

Read from **right to left**: scale first, then rotate, then translate. In general, changing the order changes the result. For example, rotating a translation can move an object around an origin, while translating after rotation places the rotated object at a fixed offset.

Transform 7 has:

```glsl
scale *= getRotationMatrixX(angle);
vec4 scaledPosition = scale * vec4(position, 1.0);
```

This is `scale * rotation * position`: rotate first, then scale. In this specific lesson the scale is uniform, so its spatial effect commutes with the rotation. Non-uniform scale generally does not.

Scale and rotation in these lessons act about the **local origin**. To rotate around some other local point `pivot`, the conceptual order is:

```text
result = translate(pivot) * rotation * translate(-pivot) * point
```

First move the pivot to the origin, then rotate, then move it back. The sample shaders do not implement this pivot adjustment.

## 6. From a transformed point to the screen

The lessons typically end with a form like:

```glsl
gl_Position = worldViewProjection * transformedPosition;
```

The host's `worldViewProjection` conventionally represents `projection * view * world`. Applied to a local point, it yields clip-space `gl_Position`.

The pipeline then clips the primitive, performs the perspective divide by clip `w`, maps NDC into the viewport, and rasterizes primitives into fragments. Do not divide by `w` in the vertex shader merely to obtain `gl_Position`; the graphics pipeline handles the appropriate clipping and perspective division.

Separately, a shader often calculates:

```glsl
vec4 worldPos = world * transformedPosition;
vPosition = worldPos.xyz;
```

`vPosition` provides a world-space point for lighting. Both calculations should use the **same local transformed position**, and the host's `world` and `worldViewProjection` should describe the same object transform.

Several lessons intentionally or incidentally do not do this: transforms 1, 3, 5, 6, 7, and 8 calculate `vPosition` from the original position but render a modified position. Their lighting can therefore use a different point from the displayed surface. The individual guides describe this behavior; no shader code is changed by this overview.

## 7. Normals and lighting

A surface **normal** describes its orientation. The common fragment shader uses the world-space normal and the direction toward a world-space light:

```glsl
vec3 normal = normalize(vNormal);
vec3 lightDir = normalize(lightPosition - vPosition);
float diff = max(dot(normal, lightDir), 0.0);
vec3 result = diff * lightColor * objectColor;
fragColor = vec4(result, 1.0);
```

1. Normalize the interpolated normal and direction to the light.
2. Take their dot product: 1 means directly facing, 0 means perpendicular, and a negative value means facing away.
3. Clamp negative values to zero.
4. Multiply by light color and object color, then write opaque output.

This is simple diffuse lighting, without ambient light, specular highlights, or distance attenuation. `lightPosition`, `vPosition`, and `vNormal` must use a consistent coordinate space.

### Why normals need special care

Normals are directions, not positions, so translation does not apply. Under a pure rotation, apply the same rotation to the normal. Under a positive uniform scale, normalization restores its original direction.

Under **non-uniform scaling or shear**, applying the ordinary position matrix to the normal can make it no longer perpendicular to the transformed surface. For an invertible linear transform `M`, use its **inverse transpose**:

```text
transformedNormal = normalize(transpose(inverse(M)) * normal)
```

The examples use `normalize(mat3(world) * normal)`, which is suitable for world rotations and uniform scale but not generally for non-uniform scale or shear. A singular transform, such as zero scale on an axis, has no ordinary inverse.

Transforms 2 and 4 also rotate the local normal with their local rotation. Transforms 3 and 7 rotate visible geometry without applying that local rotation to the lighting normal, so the lighting may not follow the shape.

## 8. Deformation: taper and twist

Unlike a single rigid rotation or uniform scale, these effects depend on the vertex's position.

### Taper based on Z

[Transform 8](./transform_8/CODE_EXPLANATION.md) changes local Y based on local Z:

```glsl
taperedPosition.y *= 1.0 + 0.95 * position.z;
```

At `z = 0`, the multiplier is 1; at `z = 1`, it is 1.95; at `z = -1`, it is 0.05. It reaches zero at approximately `z = -1.0526` and becomes negative for smaller Z, so the result depends on the mesh's coordinate range. The shader renders the tapered position but passes the original position and normal to lighting.

### Twist based on height

[Transforms 9](./transform_9/CODE_EXPLANATION.md) and [10](./transform_10/CODE_EXPLANATION.md) use:

```glsl
float angle = position.y * u_time;
float newX = position.x * cos(angle) - position.z * sin(angle);
float newZ = position.x * sin(angle) + position.z * cos(angle);
```

1. Each local height receives a different angle.
2. The XZ coordinates rotate by that angle; Y stays fixed.
3. Each vertex keeps its distance from the local Y axis, but the whole mesh twists because angles differ by height.
4. The host drives the animation by updating `u_time`.

These shaders operate on vertices; triangles are drawn between the transformed vertices. A coarse mesh is a piecewise-linear approximation of the continuous deformation, and more subdivisions can help it look smoother.

Transform 9 leaves the normal unchanged by the twist. Transform 10 rotates the normal by the local twist angle, but this is an **approximation**: the angle changes with height, so the full deformation also changes tangents through that angle gradient. Exact continuous-deformation normals require the inverse transpose of the local deformation's Jacobian, or another suitable normal reconstruction method.

## 9. Debugging checklist

- **Object does not animate:** ensure the host updates `u_time` and binds it to the active shader.
- **Rotation goes the other way:** inspect the actual matrix columns and coordinate conventions; test a known basis vector instead of guessing.
- **Object rotates around an unexpected point:** the local origin is the pivot. Check the mesh origin and transform order.
- **Shape moves but lighting looks fixed or detached:** compare the local position used for `gl_Position` with the position and normal used for `vPosition` and `vNormal`.
- **Lighting is wrong after non-uniform scale or shear:** use an appropriate inverse-transpose normal transform and verify all lighting quantities share a coordinate space.
- **Twist or taper looks faceted:** the vertex shader only moves existing vertices. Check mesh subdivision and the normal calculation.
- **Nothing is visible:** check the host's matrices, projection, clipping, viewport, geometry bindings, and draw call; a shader alone does not configure them.

## 10. Learning path

| Lesson | Main concept | Guide |
| --- | --- | --- |
| 1 | Double local scale | [Uniform scale by two](./transform_1/CODE_EXPLANATION.md) |
| 2 | Time-based Y rotation | [Animated rotation around Y](./transform_2/CODE_EXPLANATION.md) |
| 3 | Fixed 45-degree Y rotation | [Fixed Y-axis rotation](./transform_3/CODE_EXPLANATION.md) |
| 4 | Time-based X rotation | [Animated rotation around X](./transform_4/CODE_EXPLANATION.md) |
| 5 | Half local scale | [Uniform scale by one half](./transform_5/CODE_EXPLANATION.md) |
| 6 | Sine-based scale | [Animated uniform scaling](./transform_6/CODE_EXPLANATION.md) |
| 7 | Compose scale and rotation | [Combining rotation and scale](./transform_7/CODE_EXPLANATION.md) |
| 8 | Z-dependent taper | [Tapering along Z](./transform_8/CODE_EXPLANATION.md) |
| 9 | Height-dependent twist | [Twisting geometry over time](./transform_9/CODE_EXPLANATION.md) |
| 10 | Twist with approximate normal rotation | [Twisting positions and normals](./transform_10/CODE_EXPLANATION.md) |
