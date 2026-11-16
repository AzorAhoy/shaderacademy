# G-buffer 1: Visualizing World-Space Position

This example contains a [vertex shader](./vert.glsl) and a [fragment shader](./frag.glsl). It transforms a mesh into world and clip space, then displays the world-space position as RGB color. Despite the folder name, this first example writes only one color output; it does not yet create a full geometry buffer.

## What the pipeline does

1. The application supplies vertex attributes and transformation matrices.
2. The vertex shader computes each vertex's world-space position and clip-space position.
3. The GPU clips and rasterizes triangles, interpolating the world position across their fragments.
4. The fragment shader maps that position into a display color.

## Vertex shader, step by step

### 1. Select the language and precision

```glsl
#version 300 es
precision highp float;
```

GLSL ES 3.00 is the shader language used by WebGL 2. `highp` requests high-precision floating-point calculations for quantities such as positions and matrix transforms.

### 2. Receive mesh attributes

```glsl
in vec3 position;
in vec3 normal;
in vec2 uv;
```

`position` is the vertex's object-space location, `normal` is its object-space surface direction, and `uv` is its texture coordinate. The application supplies the corresponding vertex data. A normal describes a direction rather than a location; UV coordinates are typically used to locate points in a texture.

### 3. Receive transformation matrices

```glsl
uniform mat4 world;
uniform mat4 worldView;
uniform mat4 worldViewProjection;
```

Uniform values are shared by the vertices of a draw call. `world` transforms object-space positions to world space. `worldViewProjection` transforms object space to clip space; in the usual convention it combines projection, view, and world as `projection * view * world`. `worldView` is declared but not used in this shader.

### 4. Declare the values sent to the fragment shader

```glsl
out vec3 vNormal;
out vec3 vPosition;
out vec2 v_uv;
```

The matching fragment shader declares these as inputs. The GPU normally performs perspective-correct interpolation across each rasterized triangle. This example's fragment shader uses `vPosition`, but not `vNormal` or `v_uv`.

### 5. Transform the position into world space

```glsl
vec4 worldPos = world * vec4(position, 1.0);
vPosition = worldPos.xyz;
```

Appending `1.0` gives the position a homogeneous `w` component, allowing the world matrix's translation to affect it. The resulting `xyz` is sent onward as the world-space position. For example, with an identity world matrix, object position `(1, 0, -1)` remains `(1, 0, -1)` in world space.

### 6. Transform the normal and forward UVs

```glsl
vNormal = normalize(mat3(world) * normal);
v_uv = uv;
```

`mat3(world)` extracts the upper-left 3-by-3 part of the world transform; `normalize` makes the transformed direction unit length. This simple normal transform works for rotations and uniform scaling. With non-uniform scaling or shear, a normal generally needs the inverse transpose of the world matrix's linear part instead.

The UV is passed through unchanged. Both outputs are present for consistency with later examples but do not influence this example's color.

### 7. Produce the clip-space position

```glsl
gl_Position = worldViewProjection * vec4(position, 1.0);
```

`gl_Position` is the vertex shader's required position output. The GPU clips the primitive, divides clip coordinates by `w` to obtain normalized device coordinates, and maps those coordinates to the viewport before rasterization.

## Fragment shader, step by step

### 1. Receive interpolated values

```glsl
in vec3 vNormal;
in vec3 vPosition;
in vec2 v_uv;
```

These match the vertex shader outputs. At a fragment, `vPosition` represents the interpolated world-space point on the rasterized surface. The normal and UV inputs are declared but unused.

### 2. Declare the output location

```glsl
layout(location = 0) out vec4 fragColor;
```

Location 0 identifies a fragment color output. The explicit location makes its mapping clear and prepares the shader for examples that add outputs at other locations. It does **not** by itself enable multiple render targets; this shader has only one output.

### 3. Convert position to color

```glsl
vec3 positionColor = vPosition * 0.5 + 0.5;
```

The expression applies the same mapping to each component: `-1` becomes `0`, `0` becomes `0.5`, and `1` becomes `1`. World x becomes red, y becomes green, and z becomes blue.

For example, `(1, 0, -1)` maps to `(1, 0.5, 0)`, an orange color. The mapping assumes a useful position range near `[-1, 1]`; world positions outside that range produce values outside `[0, 1]`. Whether those values are clamped or preserved depends on the destination attachment's format and later display processing.

### 4. Write the color

```glsl
fragColor = vec4(positionColor, 1.0);
```

The fragment writes the mapped RGB value and opaque alpha. This is a diagnostic display of position, not a lit material. The `TODO` and placeholder comments in the source are exercise notes; the mapping itself is already present.

## What to look for

- Moving an object in world space changes its colors because `vPosition` includes the world transform.
- Large or far-from-origin objects can produce color components outside the displayable range; choose a different scale or offset for a larger scene.
- The result depends on position, not lighting or normal direction. Continue with [G-buffer 2](../gbuffer_2/CODE_EXPLANATION.md) to store and visualize depth.
