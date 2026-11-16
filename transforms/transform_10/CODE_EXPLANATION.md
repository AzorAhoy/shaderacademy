# Transform 10: Twisting Positions and Normals

Explore the effect visually in the [transformation explorer](../transform-demo.html); select lesson 10.

The [vertex shader](./vert.glsl) twists geometry according to local height and time, and also rotates each input normal by the local twist angle. The [fragment shader](./frag.glsl) applies diffuse lighting. The host provides mesh data, transforms, light uniforms, and an updating `u_time`.

## Vertex shader

### 1. Receive inputs and declare outputs

`#version 300 es` selects GLSL ES 3.00 and `highp` requests high-precision floats. The `position` and `normal` attributes are local-space mesh data; `uv` is a texture coordinate. `world` transforms local to world space, and `worldViewProjection` normally combines projection * view * world. `worldView` is unused.

`vPosition`, `vNormal`, and `v_uv` are passed to fragments. The fragment shader does not use UV. The host supplies and updates `u_time`.

### 2. Choose the twist angle

```glsl
float spiralAngle = position.y * u_time;
vec3 spiralPosition = position;
float cosAngle = cos(spiralAngle);
float sinAngle = sin(spiralAngle);
```

The angle is in radians and depends on local Y. At time 0 every vertex has angle 0; at time 1, a vertex at `y = 1` rotates by 1 radian while a vertex at `y = 0` does not rotate. Different heights rotate by different amounts, so this is not a rigid-body rotation.

### 3. Rotate the vertex's XZ coordinates

```glsl
float newX = spiralPosition.x * cosAngle - spiralPosition.z * sinAngle;
float newZ = spiralPosition.x * sinAngle + spiralPosition.z * cosAngle;
spiralPosition.x = newX;
spiralPosition.z = newZ;
```

The code computes both components before assigning them, preserving the original x and z for both calculations. Y remains unchanged. At a positive 90-degree angle, `(1, y, 0)` becomes approximately `(0, y, 1)`. Each vertex preserves its distance from the local Y axis.

Despite the source comment about preserving cube shape, the whole mesh is twisted because angles vary with height. The shader deforms vertices only; rasterized triangles connect those transformed vertices, so a coarse mesh approximates the continuous twist.

### 4. Rotate the normal approximately

```glsl
float normalX = normal.x * cosAngle - normal.z * sinAngle;
float normalZ = normal.x * sinAngle + normal.z * cosAngle;
vec3 rotatedNormal = vec3(normalX, normal.y, normalZ);
```

The same local XZ rotation is applied to the normal while its Y component is left unchanged. This improves on [transform 9](../transform_9/CODE_EXPLANATION.md), which does not rotate the normal at all. The `TODO` is an exercise prompt; these statements are present.

However, this is **not generally the exact normal of the twisted surface**. The angle changes with Y, so the deformation also shears tangents as height changes. Simply rotating a normal ignores that angle gradient. Exact continuous-deformation normals require the inverse transpose of the local deformation's Jacobian, or another suitable normal reconstruction method.

For example, at local `(0, 0, 1)` with `u_time = 1`, the angle is zero. The code leaves an input normal `(1, 0, 0)` unchanged, while the continuous twist's normal direction there is proportional to `(1, 1, 0)`. This illustrates the missing height-dependent term.

### 5. Produce world and clip outputs

```glsl
vec4 worldPos = world * vec4(spiralPosition, 1.0);
vPosition = worldPos.xyz;
vNormal = normalize(mat3(world) * rotatedNormal);
v_uv = uv;
gl_Position = worldViewProjection * vec4(spiralPosition, 1.0);
```

Both world and clip positions use the deformed point. The approximately rotated normal is transformed into world space and normalized. `mat3(world)` is suitable for rotation and uniform scale; non-uniform world scale or shear generally needs an inverse-transpose normal matrix in addition to handling the local twist.

## Fragment shader

### 1. Receive the surface and light

The fragment shader uses interpolated `vPosition` and `vNormal` with host-provided world-space `lightPosition` and RGB `lightColor` and `objectColor`. The UV varying is unused.

### 2. Compute and output diffuse illumination

```glsl
vec3 normal = normalize(vNormal);
vec3 lightDir = normalize(lightPosition - vPosition);
float diff = max(dot(normal, lightDir), 0.0);
vec3 diffuse = diff * lightColor;
vec3 result = diffuse * objectColor;
fragColor = vec4(result, 1.0);
```

The shader renormalizes the interpolated normal and finds the normalized direction to the light. Their dot product is clamped to zero, multiplied by the light and object colors, and output with alpha 1. There is no ambient, specular, or distance attenuation. Because the vertex normal transform is approximate, the lighting is also approximate.
