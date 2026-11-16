# Transform 2: Animated Rotation Around Y

Explore the effect visually in the [transformation explorer](../transform-demo.html); select lesson 2.

The [vertex shader](./vert.glsl) rotates geometry and normals about the local Y axis over time. The [fragment shader](./frag.glsl) uses those world-space values for diffuse lighting. The host must provide geometry, matrices, light uniforms, and a time value.

## Vertex shader

### 1. Receive the data

`#version 300 es` selects GLSL ES 3.00 and `highp` requests high-precision floats. `position`, `normal`, and `uv` are mesh attributes in local space, except UV which is a texture coordinate. `world` maps local to world space; `worldViewProjection` normally combines projection * view * world. `worldView` is declared but unused.

The host updates `u_time`. The shader passes `vPosition`, `vNormal`, and `v_uv` to the fragment stage; UV is unused there.

### 2. Construct the rotation matrix

```glsl
mat4 getRotationMatrix(float angle) {
    return mat4(
        cos(angle), 0.0, sin(angle), 0.0,
        0.0,        1.0, 0.0,        0.0,
       -sin(angle), 0.0, cos(angle), 0.0,
        0.0,        0.0, 0.0,        1.0
    );
}
```

GLSL fills a matrix constructor by **columns**. With `c = cos(angle)` and `s = sin(angle)`, multiplication gives `x' = c*x - s*z`, `y' = y`, and `z' = s*x + c*z`. Thus a positive 90-degree angle sends local `(1, 0, 0)` to approximately `(0, 0, 1)`; do not assume a rotation direction without checking the matrix convention.

### 3. Calculate the animation angle

```glsl
const float PI = 3.14159265359;
float angle = u_time * PI / 4.0;
mat4 rotation = getRotationMatrix(angle);
```

At `u_time = 0`, the angle is 0; at 1 it is 45 degrees; at 2 it is 90 degrees; at 8 it reaches a full turn. If the host measures time in seconds, the speed is 45 degrees per second and the period is 8 seconds. The source's `TODO` is an exercise prompt; the time-based calculation is already present.

### 4. Rotate position and normal

```glsl
vec4 modifiedPosition = rotation * vec4(position, 1.0);
vec3 rotatedNormal = normalize(mat3(rotation) * normal);
```

The position rotates about the local origin. Rotation does not translate it, so `w` remains 1. The normal is rotated by the same rotation, without translation, and normalized.

### 5. Produce world and clip outputs

```glsl
vec4 worldPos = world * modifiedPosition;
vPosition = worldPos.xyz;
vNormal = normalize(mat3(world) * rotatedNormal);
v_uv = uv;
gl_Position = worldViewProjection * modifiedPosition;
```

Both `vPosition` and `gl_Position` use the rotated position, keeping lighting position consistent with geometry. The normal is also rotated before the world transform. `mat3(world)` is adequate for rotation and uniform scale; non-uniform scale or shear generally needs an inverse-transpose normal matrix.

## Fragment shader

### 1. Read the surface and light

The fragment shader receives interpolated `vPosition` and `vNormal`, plus `lightPosition`, `lightColor`, and `objectColor` uniforms from the host. The light position must be in world space. `v_uv` is declared but unused.

### 2. Compute the diffuse response

```glsl
vec3 normal = normalize(vNormal);
vec3 lightDir = normalize(lightPosition - vPosition);
float diff = max(dot(normal, lightDir), 0.0);
vec3 diffuse = diff * lightColor;
```

Interpolation can change normal length, so the shader normalizes it again. The dot product measures how directly the normal faces the light; clamping prevents negative diffuse contribution.

### 3. Output the lit color

```glsl
vec3 result = diffuse * objectColor;
fragColor = vec4(result, 1.0);
```

The output is opaque diffuse RGB. There is no ambient, specular, or distance attenuation. Update `u_time` in the host or the rotation will remain static.
