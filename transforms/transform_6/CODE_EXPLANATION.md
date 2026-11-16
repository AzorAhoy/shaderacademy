# Transform 6: Animated Uniform Scaling

Explore the effect visually in the [transformation explorer](../transform-demo.html); select lesson 6.

The [vertex shader](./vert.glsl) changes the mesh's local scale with a sine wave. The [fragment shader](./frag.glsl) applies simple diffuse lighting. The host supplies the geometry, matrices, lighting values, and an updating `u_time`.

## Vertex shader

### 1. Receive inputs and declare varyings

`#version 300 es` selects GLSL ES 3.00, used by WebGL 2, and `highp` requests high-precision floats. `position` and `normal` are local-space mesh attributes; `uv` is a texture coordinate. `world` maps local to world space, and `worldViewProjection` normally combines projection * view * world. `worldView` is declared but unused.

The shader sends `vPosition`, `vNormal`, and `v_uv` to the fragment stage. That stage does not use UV. The host must provide time in consistent units and update it for animation.

### 2. Calculate a time-varying scale

```glsl
float s = 1.0 + 0.5 * sin(u_time);
```

`sin` ranges from -1 to 1, so `s` ranges from 0.5 to 1.5. The scale oscillates around 1:

| `u_time` | `sin(u_time)` | Scale |
| --- | --- | --- |
| `0` | `0` | `1.0` |
| `pi / 2` | `1` | `1.5` |
| `pi` | `0` | `1.0` |
| `3*pi / 2` | `-1` | `0.5` |

The sine argument is in radians. The period is `2*pi` units of `u_time`; if the host uses seconds, the cycle takes approximately 6.28 seconds. The source's `TODO` is an exercise prompt; this calculation is already implemented.

### 3. Scale the local position

```glsl
mat4 scale = mat4(
    s,   0.0, 0.0, 0.0,
    0.0, s,   0.0, 0.0,
    0.0, 0.0, s,   0.0,
    0.0, 0.0, 0.0, 1.0
);
vec4 scaledPosition = scale * vec4(position, 1.0);
```

The same positive factor applies to x, y, and z about the local origin; `w` stays 1. For example, with `s = 1.5`, `(2, -1, 0)` becomes `(3, -1.5, 0)`.

### 4. Produce world and clip outputs

```glsl
vec4 worldPos = world * vec4(position, 1.0);
vPosition = worldPos.xyz;
vNormal = normalize(mat3(world) * normal);
v_uv = uv;
gl_Position = worldViewProjection * scaledPosition;
```

The visible clip position uses `scaledPosition`, but the world position used for lighting comes from the original vertex. Except when `s = 1`, the position used for lighting can differ from the displayed surface. A consistent implementation would use `scaledPosition` for `worldPos`.

The scale is always positive and uniform, so it does not change the normal's direction after normalization. `mat3(world)` is suitable for rotations and uniform scale of the world transform; non-uniform scaling or shear generally requires an inverse-transpose normal matrix.

## Fragment shader

### 1. Receive surface and light data

The interpolated `vPosition` and `vNormal` are used with host-provided world-space `lightPosition`, `lightColor`, and `objectColor`. The UV varying is unused.

### 2. Compute diffuse color

```glsl
vec3 normal = normalize(vNormal);
vec3 lightDir = normalize(lightPosition - vPosition);
float diff = max(dot(normal, lightDir), 0.0);
vec3 diffuse = diff * lightColor;
vec3 result = diffuse * objectColor;
fragColor = vec4(result, 1.0);
```

The shader normalizes the interpolated normal and light direction, clamps their dot product to zero, multiplies by light and object colors, and writes opaque RGB. There is no ambient, specular, or attenuation term. The unscaled `vPosition` means the light direction may not match the animated surface.

If the mesh does not pulse, check that the host updates `u_time`; if the lighting looks detached, inspect the world-position mismatch.
