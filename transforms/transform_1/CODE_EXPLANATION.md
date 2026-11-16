# Transform 1: Uniform Scale by Two

Explore the effect visually in the [transformation explorer](../transform-demo.html); select lesson 1.

The [vertex shader](./vert.glsl) doubles an object's local coordinates for its rendered shape. The [fragment shader](./frag.glsl) applies simple diffuse lighting. The host supplies the geometry, matrices, light and object colors, and draw call; these shaders do not create a scene.

## Vertex shader

### 1. Select the language and inputs

`#version 300 es` selects GLSL ES 3.00, used by WebGL 2; `precision highp float` requests high-precision floating-point arithmetic. The `position`, `normal`, and `uv` attributes are the mesh's local-space position, local-space normal, and texture coordinate.

The host provides `world` (local to world) and `worldViewProjection` (local to clip space, conventionally projection * view * world). `worldView` is declared but unused. The `vPosition`, `vNormal`, and `v_uv` outputs go to the fragment shader and are normally interpolated across triangles.

### 2. Prepare lighting inputs

```glsl
vec4 worldPos = world * vec4(position, 1.0);
vPosition = worldPos.xyz;
vNormal = normalize(mat3(world) * normal);
v_uv = uv;
```

The `1.0` makes the position a homogeneous point so translation applies. `vPosition` is the world-space position and `vNormal` is the normalized transformed normal. The UV is forwarded but not used by the fragment shader. `mat3(world)` is sufficient for rotations and uniform scaling; non-uniform scaling or shear generally needs an inverse-transpose normal matrix.

**Important:** this position is calculated from the original vertex, before the local scale below. The visible geometry and the position used by lighting therefore do not generally match. A consistent implementation would calculate world position from `scaled`; this guide describes the existing shader.

### 3. Define unused angle values

```glsl
const float PI = 3.14159265359;
float angle = PI / 4.0;
```

`angle` is 45 degrees in radians, but neither it nor `PI` affects the final position. This lesson performs no rotation.

### 4. Build and apply the scale

```glsl
mat4 scale = mat4(
    2.0, 0.0, 0.0, 0.0,
    0.0, 2.0, 0.0, 0.0,
    0.0, 0.0, 2.0, 0.0,
    0.0, 0.0, 0.0, 1.0
);
vec4 scaled = scale * vec4(position, 1.0);
gl_Position = worldViewProjection * scaled;
```

The matrix scales x, y, and z by 2 and leaves homogeneous `w` at 1. For example, `(1, -0.5, 0.25)` becomes `(2, -1, 0.5)` in local space. The scale is about the local origin, before the host's world transform. A uniform positive scale does not change a normal's direction after normalization.

`gl_Position` is the clip-space output used for clipping, perspective division, and rasterization.

## Fragment shader

### 1. Receive lighting inputs

`vNormal` and `vPosition` are the interpolated world-space normal and position; `v_uv` is unused. The host supplies `lightPosition` in world space, along with RGB `lightColor` and `objectColor`.

### 2. Calculate diffuse illumination

```glsl
vec3 normal = normalize(vNormal);
vec3 lightDir = normalize(lightPosition - vPosition);
float diff = max(dot(normal, lightDir), 0.0);
vec3 diffuse = diff * lightColor;
```

The shader renormalizes the interpolated normal and finds the direction from the supplied position to the light. The dot product is 1 when unit vectors align, 0 when perpendicular, and negative when facing away; `max` removes negative light. Because `vPosition` comes from the unscaled mesh, light direction can be wrong for the displayed surface.

### 3. Apply the object color

```glsl
vec3 result = diffuse * objectColor;
fragColor = vec4(result, 1.0);
```

The RGB product is the opaque output. There is no ambient term, attenuation, texture sampling, or specular highlight, so surfaces facing away from the light are black.
