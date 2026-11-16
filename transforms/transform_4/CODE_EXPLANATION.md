# Transform 4: Animated Rotation Around X

Explore the effect visually in the [transformation explorer](../transform-demo.html); select lesson 4.

The [vertex shader](./vert.glsl) rotates local positions and normals around X as time advances. The [fragment shader](./frag.glsl) shades them with a simple diffuse light. The host supplies the geometry, camera and world matrices, time, and light values.

## Vertex shader

### 1. Receive inputs

`#version 300 es` selects GLSL ES 3.00 for WebGL 2, while `highp` requests high-precision floats. The `position`, `normal`, and `uv` attributes describe the mesh. `world` maps local to world space; `worldViewProjection` normally combines projection * view * world. `worldView` is declared but unused. `u_time` comes from the host.

The outputs `vPosition`, `vNormal`, and `v_uv` are interpolated for the fragment shader. UV is forwarded but unused by that shader.

### 2. Build the X rotation matrix

```glsl
mat4 getRotationMatrixX(float angle) {
    return mat4(
        1.0, 0.0,        0.0,       0.0,
        0.0, cos(angle), -sin(angle), 0.0,
        0.0, sin(angle),  cos(angle), 0.0,
        0.0, 0.0,        0.0,       1.0
    );
}
```

GLSL matrix constructors are filled by columns. If `c = cos(angle)` and `s = sin(angle)`, multiplication gives `x' = x`, `y' = c*y + s*z`, and `z' = -s*y + c*z`. At a positive 90-degree angle, `(0, 1, 0)` becomes approximately `(0, 0, -1)`.

### 3. Animate the angle

```glsl
const float PI = 3.14159265359;
float angle = u_time * PI / 4.0;
mat4 rotation = getRotationMatrixX(angle);
```

The angle starts at zero and grows by 45 degrees per unit of `u_time`; at time 2 it is 90 degrees and at time 8 it completes a turn. These become degrees per second and seconds per turn if the host uses seconds. The `TODO` comments and the comment about keeping output unrotated are stale exercise notes: the code does perform the rotation.

### 4. Rotate the position and normal

```glsl
vec4 modifiedPosition = rotation * vec4(position, 1.0);
vec3 rotatedNormal = normalize(mat3(rotation) * normal);
```

The position rotates about the local origin. The normal receives the same rotation without translation and is normalized.

### 5. Produce world-space varyings and clip position

```glsl
vec4 worldPos = world * modifiedPosition;
vPosition = worldPos.xyz;
vNormal = normalize(mat3(world) * rotatedNormal);
v_uv = uv;
gl_Position = worldViewProjection * modifiedPosition;
```

Both visible position and lighting position use the rotated vertex; the normal is rotated too. The world-space normal calculation is sufficient for rotations and uniform scale of `world`, but non-uniform scaling or shear generally needs its inverse-transpose normal matrix. The clip-space output is used for clipping and rasterization.

## Fragment shader

### 1. Read surface and light values

The fragment shader receives `vPosition` and `vNormal`; UV is unused. The host provides `lightPosition` in world space, along with `lightColor` and `objectColor`.

### 2. Compute and write diffuse color

```glsl
vec3 normal = normalize(vNormal);
vec3 lightDir = normalize(lightPosition - vPosition);
float diff = max(dot(normal, lightDir), 0.0);
vec3 diffuse = diff * lightColor;
vec3 result = diffuse * objectColor;
fragColor = vec4(result, 1.0);
```

The shader renormalizes the interpolated normal, finds the direction to the light, and clamps their dot product to avoid negative light. It multiplies that factor by light and object colors and outputs opaque RGB. There is no ambient, specular, or distance attenuation. If the object is not moving, ensure the host updates `u_time`.
