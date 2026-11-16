# Transform 9: Twisting Geometry Over Time

Explore the effect visually in the [transformation explorer](../transform-demo.html); select lesson 9.

The [vertex shader](./vert.glsl) rotates each vertex's XZ coordinates by an angle based on its local Y coordinate and time. The [fragment shader](./frag.glsl) applies diffuse light. The host must provide the mesh, matrices, light values, and an updating `u_time`.

## Vertex shader

### 1. Receive inputs and declare outputs

`#version 300 es` selects GLSL ES 3.00 and `highp` requests high-precision floats. `position` and `normal` are local-space attributes, and `uv` is a texture coordinate. `world` maps local to world space; `worldViewProjection` normally combines projection * view * world. `worldView` is unused.

The shader sends world position, world normal, and UV through `vPosition`, `vNormal`, and `v_uv`. UV is unused by the fragment shader. The host updates `u_time`; the code does not define its units or a reset behavior.

### 2. Set an angle for each height

```glsl
float spiralAngle = position.y * u_time;
```

The angle is in radians. At `u_time = 0`, all angles are zero. At a fixed nonzero time, vertices at different local heights receive different angles, creating a twist. For example, at time `1`, local `y = 0` has angle `0`, while local `y = 1` has angle `1` radian.

This is not a single rigid rotation: the angle depends on height. The `TODO` comments are exercise prompts; the twist is already implemented.

### 3. Rotate the XZ coordinates

```glsl
vec3 spiralPosition = position;
float cosAngle = cos(spiralAngle);
float sinAngle = sin(spiralAngle);
float newX = position.x * cosAngle - position.z * sinAngle;
float newZ = position.x * sinAngle + position.z * cosAngle;
spiralPosition.x = newX;
spiralPosition.z = newZ;
```

For each vertex, the 2D rotation maps `(x, z)` to `(x*cos - z*sin, x*sin + z*cos)` and leaves Y unchanged. At a positive 90-degree angle, `(1, y, 0)` becomes approximately `(0, y, 1)`.

The rotation preserves each vertex's distance `sqrt(x*x + z*z)` from the local Y axis. It does **not** make the entire cube a rigid shape: different heights rotate by different amounts. The deformation is computed only at vertices, and the GPU draws planar triangles between them; additional mesh subdivisions can better approximate a smooth twist.

### 4. Transform the deformed position

```glsl
vec4 worldPos = world * vec4(spiralPosition, 1.0);
vPosition = worldPos.xyz;
vNormal = normalize(mat3(world) * normal);
v_uv = uv;
gl_Position = worldViewProjection * vec4(spiralPosition, 1.0);
```

Both clip position and world-space lighting position use the twisted point. However, the normal remains the original local normal transformed only by `world`; it does not follow the twist. Lighting may therefore disagree with the visible surface.

The simple world normal transform works for rotations and uniform scale; non-uniform world scale or shear generally needs an inverse-transpose normal matrix. A position-dependent twist also requires accounting for the deformation when transforming normals.

## Fragment shader

### 1. Receive the surface and light

`vPosition` and `vNormal` are interpolated from the vertex stage. The host supplies world-space `lightPosition`, `lightColor`, and `objectColor`. The UV varying is unused.

### 2. Compute diffuse color

```glsl
vec3 normal = normalize(vNormal);
vec3 lightDir = normalize(lightPosition - vPosition);
float diff = max(dot(normal, lightDir), 0.0);
vec3 diffuse = diff * lightColor;
vec3 result = diffuse * objectColor;
fragColor = vec4(result, 1.0);
```

The shader normalizes the interpolated normal and direction toward the light, clamps their dot product, and multiplies by the light and object colors. It writes opaque RGB with no ambient, specular, or attenuation component. Because the normal does not follow the twist, the diffuse response can be misleading.

Compare [transform 10](../transform_10/CODE_EXPLANATION.md), which also rotates the normal but still approximates the full deformation.
