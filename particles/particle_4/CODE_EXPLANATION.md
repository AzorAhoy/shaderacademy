# Particle 4: Moving Points Toward Three Targets

The [vertex shader](./vert.glsl) assigns each vertex to one of three groups and moves it from its original position toward that group's target. The [fragment shader](./frag.glsl) colors the groups red, green, and blue.

The host application must supply the geometry, matrices, animation uniforms, and draw call. To see individual particles, it must draw point primitives. These shaders do not create or simulate a particle system on their own.

## 1. Overview

1. Use the vertex ID to choose a group from 0, 1, and 2.
2. Select one of three fixed target positions in object space.
3. Use the time ratio to interpolate from the original position to the target.
4. Transform the animated position to world and clip space.
5. Pass the group number to the fragment shader.
6. Color the point red, green, or blue according to its group.

The three targets form the corners of a triangle in the local XY plane. The shader does not fill the triangle or move particles along its edges: each point moves directly toward its assigned corner.

## 2. Vertex shader, step by step

### Step 1: Choose the language and precision

```glsl
#version 300 es
precision highp float;
```

GLSL ES 3.00 is used by WebGL 2. `highp` requests high-precision floating-point arithmetic for position, time, and matrix calculations.

### Step 2: Receive mesh attributes

```glsl
in vec3 position;
in vec3 normal;
in vec2 uv;
```

The host provides the original object-space position, object-space normal, and UV coordinate for each vertex. The normal and UV are forwarded, but the current fragment shader does not use them; unused attributes or varyings can be optimized away.

### Step 3: Receive transformation and time uniforms

```glsl
uniform mat4 world;
uniform mat4 worldView;
uniform mat4 worldViewProjection;
uniform float u_time;
uniform float u_maxTime;
```

- `world` transforms object-space positions to world space.
- `worldView` is declared but unused.
- `worldViewProjection` transforms object space to clip space; conventionally it combines projection, view, and world in that order.
- `u_time` is the current animation time.
- `u_maxTime` is the time at which interpolation reaches the target.

The host should supply time values in the same units and use a positive, nonzero `u_maxTime`. The shader divides by it without guarding against zero.

### Step 4: Declare the values sent to fragments

```glsl
out vec3 vNormal;
out vec3 vPosition;
out vec2 v_uv;
flat out int vPointGroup;
```

The fragment shader has matching inputs. `vPosition` carries the animated world-space position; `vNormal` and `v_uv` carry the transformed normal and original UV. None of those three affects the current fragment color.

`vPointGroup` is an integer group ID. The `flat` qualifier means it is not interpolated across a primitive; the fragment shader also declares it `flat`. For point primitives, each point has a single vertex and therefore one group for all its fragments.

### Step 5: Pick a group using the vertex ID

```glsl
int vertexId = gl_VertexID;
int triangleIndex = vertexId % 3;
```

`gl_VertexID` identifies the vertex being processed. `% 3` cycles through 0, 1, and 2 for consecutive IDs:

| Vertex ID | Group |
| --- | --- |
| 0 | 0 |
| 1 | 1 |
| 2 | 2 |
| 3 | 0 |
| 4 | 1 |
| 5 | 2 |

Despite the name `triangleIndex`, the value selects a target corner, not a triangle in the mesh. With indexed drawing, the ID is based on the referenced vertex index; with a non-indexed draw it includes the draw's starting vertex. Thus group assignment depends on the draw and indices, not simply on the order in which the shader happens to execute.

### Step 6: Initialize the position and group

```glsl
vec3 originalPos = position;
vec3 newPos = originalPos;
vPointGroup = 0;
```

The shader saves the starting position and sets defaults. Later statements overwrite `newPos` and `vPointGroup` for every vertex, so these initial values do not determine the final result in the current code.

### Step 7: Define the three targets

```glsl
vec3 trianglePositions[3] = vec3[3](
    vec3(-2.0, -1.0, 0.0),
    vec3(2.0, -1.0, 0.0),
    vec3(0.0, 2.0, 0.0)
);
```

The array contains fixed object-space targets:

| Group | Target | Fragment color |
| --- | --- | --- |
| 0 | `(-2, -1, 0)` | Red |
| 1 | `(2, -1, 0)` | Green |
| 2 | `(0, 2, 0)` | Blue |

All target z coordinates are zero. The world transform subsequently positions the entire arrangement in the scene.

### Step 8: Compute progress and move toward the target

```glsl
float progress = u_time / u_maxTime;
newPos = mix(originalPos, trianglePositions[triangleIndex], progress);
vPointGroup = triangleIndex;
```

`mix(a, b, t)` calculates `a * (1 - t) + b * t` component by component:

1. At `progress = 0`, `newPos` is the original position.
2. At `progress = 0.5`, it is halfway from the original position to the chosen target.
3. At `progress = 1`, it reaches that target.

For example, a group 0 point starting at `(0, 0, 0)` is at `(-1, -0.5, 0)` when progress is `0.5`.

The shader does **not** clamp or wrap `progress`. A value above 1 extrapolates beyond the target; a negative value extrapolates away from it. The host can control the time range if stopping or looping is desired. The `TODO` comments are exercise prompts: the interpolation and group assignment are already present.

### Step 9: Set the point size

```glsl
gl_PointSize = 1.5;
```

When drawing point primitives, this requests a point size of 1.5 pixels. The effective size is subject to the implementation's supported point-size range and rasterization rules. It does not set the size of triangle primitives.

### Step 10: Transform the animated point

```glsl
vec4 worldPos = world * vec4(newPos, 1.0);
vPosition = worldPos.xyz;
vNormal = normalize(mat3(world) * normal);
v_uv = uv;
gl_Position = worldViewProjection * vec4(newPos, 1.0);
```

Both world and clip positions use `newPos`, so the displayed geometry follows the animation. `vPosition` is the world-space point; `gl_Position` is the clip-space position used for clipping and rasterization.

The simple `mat3(world)` normal transform is suitable for rotations and uniform scaling. Non-uniform scale or shear generally requires the inverse transpose of the world matrix's linear part. The transformed normal is unused by this example's fragment shader.

## 3. Fragment shader, step by step

### Step 1: Receive interpolated values and uniforms

```glsl
in vec3 vNormal;
in vec3 vPosition;
in vec2 v_uv;
flat in int vPointGroup;

uniform vec3 lightPosition;
uniform vec3 lightColor;
uniform vec3 objectColor;
uniform float shininess;
```

Only `vPointGroup` is used. The position, normal, UV, and lighting uniforms are declared but do not influence this shader's output; no lighting calculation is performed.

### Step 2: Choose the group color

```glsl
vec3 color = vec3(1.0, 1.0, 1.0);
if (vPointGroup == 0) {
    color = vec3(1.0, 0.0, 0.0);
} else if (vPointGroup == 1) {
    color = vec3(0.0, 1.0, 0.0);
} else {
    color = vec3(0.0, 0.0, 1.0);
}
```

Group 0 is red, group 1 is green, and all other values are blue. With the vertex shader's modulo calculation, the other value is group 2. The initial white is overwritten in every branch.

### Step 3: Write an opaque color

```glsl
fragColor = vec4(color, 1.0);
```

The shader outputs the chosen RGB with alpha 1. It does not sample a texture or use a point-coordinate mask, so point shape and appearance depend on point rasterization rather than a circular sprite mask.

## 4. Things to check

- **Nothing moves:** update `u_time` in the host and supply a nonzero `u_maxTime`.
- **Points overshoot:** the time ratio is not clamped; keep it in `[0, 1]` if the intended motion should stop at the corners.
- **Unexpected group order:** check the draw's starting vertex or index buffer; the group is based on `gl_VertexID`.
- **Not seeing point sprites:** ensure the host draws points, and check its supported point-size range.

Compare this fixed-target animation with [particle 2](../particle_2/CODE_EXPLANATION.md), which uses pseudo-random targets.
