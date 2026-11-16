# Transform 7: Combining Rotation and Scale

Explore the effect visually in the [transformation explorer](../transform-demo.html); select lesson 7.

The [vertex shader](./vert.glsl) applies a fixed 135-degree local X rotation and a uniform 1.5 scale. The [fragment shader](./frag.glsl) computes diffuse light. The host supplies mesh attributes, transformation matrices, and light values.

## Vertex shader

### 1. Declare inputs and outputs

The shader uses GLSL ES 3.00 (`#version 300 es`) with high-precision floats. The `position` and `normal` attributes are local-space mesh data, and `uv` is a texture coordinate. `world` converts local to world space; `worldViewProjection` normally combines projection * view * world. `worldView` is unused.

The vertex shader passes `vPosition`, `vNormal`, and `v_uv` to the fragment shader; the latter does not use UV.

### 2. Define the X rotation

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

GLSL fills constructor values by columns. With `c = cos(angle)` and `s = sin(angle)`, the result is `x' = x`, `y' = c*y + s*z`, and `z' = -s*y + c*z`. Positive 90 degrees sends `(0, 1, 0)` to approximately `(0, 0, -1)`.

### 3. Set the angle and build the scale

```glsl
const float PI = 3.14159265359;
float angle = 3.0 * PI / 4.0;
mat4 scale = mat4(
    1.5, 0.0, 0.0, 0.0,
    0.0, 1.5, 0.0, 0.0,
    0.0, 0.0, 1.5, 0.0,
    0.0, 0.0, 0.0, 1.0
);
```

`3*pi/4` is 135 degrees. The matrix scales x, y, and z by 1.5 about the local origin, preserving homogeneous `w`. Both operations are fixed; no time uniform drives this shader.

### 4. Compose and apply the matrices

```glsl
scale *= getRotationMatrixX(angle);
vec4 scaledPosition = scale * vec4(position, 1.0);
```

The compound assignment means `scale = scale * rotation`. Matrix-vector multiplication applies the rightmost operation first: the point is rotated, then scaled. Here the scale is uniform, so its spatial effect commutes with rotation; do not assume that is true for non-uniform scale or other transforms.

For local `(0, 1, 0)`, the rotation yields approximately `(0, -0.7071, -0.7071)` and scaling gives `(0, -1.0607, -1.0607)`. The `TODO` comment is an exercise prompt; both operations are present.

### 5. Produce lighting inputs and clip position

```glsl
vec4 worldPos = world * vec4(position, 1.0);
vPosition = worldPos.xyz;
vNormal = normalize(mat3(world) * normal);
v_uv = uv;
gl_Position = worldViewProjection * scaledPosition;
```

The clip output uses the combined transform, but `vPosition` and `vNormal` use the original vertex and normal. Consequently, the lighting position and orientation do not generally match the displayed surface. A matching implementation would also use the transformed position and rotate the normal before applying the world transform.

`mat3(world)` handles world rotations and uniform scales; non-uniform scale or shear generally needs an inverse-transpose normal matrix.

## Fragment shader

### 1. Read the surface and light

`vPosition` and `vNormal` are interpolated from the vertex stage; `v_uv` is unused. The host supplies world-space `lightPosition` and RGB `lightColor` and `objectColor`.

### 2. Evaluate diffuse illumination

```glsl
vec3 normal = normalize(vNormal);
vec3 lightDir = normalize(lightPosition - vPosition);
float diff = max(dot(normal, lightDir), 0.0);
vec3 diffuse = diff * lightColor;
vec3 result = diffuse * objectColor;
fragColor = vec4(result, 1.0);
```

The shader renormalizes the normal, finds a unit direction to the light, and clamps their dot product. It multiplies that diffuse factor by the light and object colors and writes opaque RGB. There is no ambient, specular, or distance attenuation. Because the varyings were not transformed with the geometry, lighting can appear incorrect.
