# Transform 5: Uniform Scale by One Half

Explore the effect visually in the [transformation explorer](../transform-demo.html); select lesson 5.

The [vertex shader](./vert.glsl) scales local geometry to half its size. The [fragment shader](./frag.glsl) uses diffuse lighting. Geometry, transforms, and lighting uniforms come from the host application.

## Vertex shader

### 1. Receive mesh data and transforms

`#version 300 es` and `precision highp float` select GLSL ES 3.00 and high-precision floats. `position` and `normal` are local-space mesh attributes; `uv` is a texture coordinate. `world` maps local space to world space, while `worldViewProjection` normally combines projection * view * world. `worldView` is unused.

`vPosition`, `vNormal`, and `v_uv` are sent to the fragment shader. UV is not used by that shader.

### 2. Construct a scale matrix

```glsl
mat4 scale = mat4(
    0.5, 0.0, 0.0, 0.0,
    0.0, 0.5, 0.0, 0.0,
    0.0, 0.0, 0.5, 0.0,
    0.0, 0.0, 0.0, 1.0
);
vec4 scaledPosition = scale * vec4(position, 1.0);
```

The diagonal scales all three spatial axes by `0.5` and preserves homogeneous `w`. A local point `(2, -1, 0.5)` becomes `(1, -0.5, 0.25)`. Scaling is around the local origin before applying the world transform. The `TODO` comment is an exercise prompt; the scale is present.

### 3. Prepare the varyings and output

```glsl
vec4 worldPos = world * vec4(position, 1.0);
vPosition = worldPos.xyz;
vNormal = normalize(mat3(world) * normal);
v_uv = uv;
gl_Position = worldViewProjection * scaledPosition;
```

`gl_Position` uses the scaled position, but `vPosition` is calculated from the **original** position. This mismatch can make the light direction inconsistent with the visible surface. Using `scaledPosition` for world position would align them; this guide does not change the shader.

The positive uniform scale does not change normal direction after normalization. The world normal calculation is adequate for rotations and uniform scaling, but non-uniform world scale or shear generally needs an inverse-transpose normal matrix. The source comment saying output is kept without scaling is stale: the clip output is scaled.

## Fragment shader

### 1. Read the surface and light

The shader receives interpolated `vPosition` and `vNormal`. The host supplies world-space `lightPosition` and RGB `lightColor` and `objectColor`; `v_uv` is unused.

### 2. Evaluate and output diffuse light

```glsl
vec3 normal = normalize(vNormal);
vec3 lightDir = normalize(lightPosition - vPosition);
float diff = max(dot(normal, lightDir), 0.0);
vec3 diffuse = diff * lightColor;
vec3 result = diffuse * objectColor;
fragColor = vec4(result, 1.0);
```

The shader normalizes the interpolated normal and direction toward the light, takes their dot product, and clamps it to zero. It multiplies the resulting diffuse factor by light and object colors, then writes opaque alpha. Since `vPosition` is unscaled, lighting can be calculated from the wrong location. There is no ambient, specular, or attenuation component.
