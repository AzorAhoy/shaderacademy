# Transform 3: Fixed Y-Axis Rotation

Explore the effect visually in the [transformation explorer](../transform-demo.html); select lesson 3.

The [vertex shader](./vert.glsl) rotates the rendered geometry by a fixed 45-degree angle around local Y. The [fragment shader](./frag.glsl) applies diffuse lighting. The host provides mesh data, matrices, and lighting uniforms.

## Vertex shader

### 1. Declare shader inputs and outputs

GLSL ES 3.00 (`#version 300 es`) is used by WebGL 2; `highp` requests high-precision floats. `position` and `normal` are local-space mesh attributes and `uv` is a texture coordinate. `world` transforms local space to world space; `worldViewProjection` normally combines projection * view * world. `worldView` is declared but unused.

The vertex outputs `vPosition`, `vNormal`, and `v_uv` are passed to fragments. The fragment shader does not use `v_uv`.

### 2. Prepare lighting data from the original vertex

```glsl
vec4 worldPos = world * vec4(position, 1.0);
vPosition = worldPos.xyz;
vNormal = normalize(mat3(world) * normal);
v_uv = uv;
```

`w = 1` makes the vertex a point that can be translated. The normal uses the 3-by-3 part of `world` and is normalized. For non-uniform world scale or shear, an inverse-transpose normal matrix is generally required.

These values are computed **before** the local rotation below. Consequently, lighting uses the original position and normal while the displayed geometry is rotated. Correctly matching the visible surface would require transforming both position and normal with that local rotation as well.

### 3. Compute a fixed angle

```glsl
const float PI = 3.14159265359;
float angle = PI / 4.0;
float c = cos(angle), s = sin(angle);
```

`PI / 4` is 45 degrees, approximately `0.7854` radians. `c` and `s` are each approximately `0.7071`. There is no time uniform, so this rotation is static.

### 4. Build and apply the rotation

```glsl
mat4 rotY = mat4(
    c,   0.0, s,   0.0,
    0.0, 1.0, 0.0, 0.0,
    -s,  0.0, c,   0.0,
    0.0, 0.0, 0.0, 1.0
);
vec4 rotated = rotY * vec4(position, 1.0);
gl_Position = worldViewProjection * rotated;
```

GLSL fills constructor values by columns. Multiplication yields `x' = c*x - s*z`, `y' = y`, `z' = s*x + c*z`. The local point `(1, 0, 0)` becomes approximately `(0.7071, 0, 0.7071)`. Rotation is about the local origin and occurs before the world/view/projection transform.

`gl_Position` supplies clip-space coordinates for clipping and rasterization.

## Fragment shader

### 1. Receive world-space inputs

The host supplies `lightPosition`, `lightColor`, and `objectColor`. The shader receives interpolated `vNormal` and `vPosition`; `v_uv` is unused. Light position must use the same world coordinate system as `vPosition`.

### 2. Evaluate diffuse lighting

```glsl
vec3 normal = normalize(vNormal);
vec3 lightDir = normalize(lightPosition - vPosition);
float diff = max(dot(normal, lightDir), 0.0);
vec3 diffuse = diff * lightColor;
```

The shader normalizes the interpolated normal and the vector toward the light. The dot product gives the facing factor, clamped to zero for a back-facing surface. Because the passed position and normal were not rotated, the resulting lighting can fail to follow the displayed rotation.

### 3. Output the result

```glsl
vec3 result = diffuse * objectColor;
fragColor = vec4(result, 1.0);
```

The opaque RGB output has no ambient, specular, or attenuation term. Compare [transform 2](../transform_2/CODE_EXPLANATION.md), which also rotates the lighting position and normal.
