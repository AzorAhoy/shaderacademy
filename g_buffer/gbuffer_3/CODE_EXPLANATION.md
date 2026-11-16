# G-buffer 3: Storing Depth and Surface Normals

The [vertex shader](./vert.glsl) transforms a mesh, and the [fragment shader](./frag.glsl) writes three color outputs: a normal visualization, a depth copy, and an encoded normal. This demonstrates multiple render targets (MRT), a building block of deferred rendering.

## Pipeline overview

1. The application binds the mesh, transforms, and a framebuffer with the required color attachments.
2. The vertex shader computes clip-space positions and transforms normals to world space.
3. The rasterizer generates fragments and interpolates vertex outputs.
4. The fragment shader stores depth and a normalized, encoded normal, and displays that normal as color.

## Vertex shader, step by step

### 1. Select the language and precision

```glsl
#version 300 es
precision highp float;
```

This is GLSL ES 3.00, used by WebGL 2. `highp` requests high-precision floating-point calculations for transformations and positions.

### 2. Receive the mesh data

```glsl
in vec3 position;
in vec3 normal;
in vec2 uv;
```

`position` and `normal` start in object space. `uv` is a two-dimensional texture coordinate. The application supplies these per-vertex inputs from the mesh.

### 3. Receive the transforms

```glsl
uniform mat4 world;
uniform mat4 worldView;
uniform mat4 worldViewProjection;
```

`world` transforms from object to world space. `worldViewProjection` transforms from object to clip space; conventionally it is `projection * view * world`. `worldView` is declared but not used.

### 4. Declare the values passed to fragments

```glsl
out vec3 vNormal;
out vec3 vPosition;
out vec2 v_uv;
```

The rasterizer normally interpolates these values perspective-correctly across a triangle. The fragment shader uses `vNormal`; it declares but does not use `vPosition` or `v_uv`.

### 5. Calculate the world-space position

```glsl
vec4 worldPos = world * vec4(position, 1.0);
vPosition = worldPos.xyz;
```

The homogeneous `1.0` allows the world transform to translate the point. The resulting `xyz` is passed to the fragment shader, although the current fragment code does not use it.

### 6. Calculate the world-space normal and forward the UV

```glsl
vNormal = normalize(mat3(world) * normal);
v_uv = uv;
```

The 3-by-3 part of the world matrix transforms the normal's direction, and `normalize` makes it unit length. This simple form works for rotations and uniform scaling; non-uniform scaling or shear generally requires the inverse transpose of the world matrix's linear part. The UV is passed unchanged and is unused in the fragment shader.

Even when each vertex normal is normalized, an interpolated normal between vertices may no longer have unit length. The fragment shader normalizes it again.

### 7. Output the clip-space position

```glsl
gl_Position = worldViewProjection * vec4(position, 1.0);
```

The pipeline uses this position for clipping and, after perspective division and viewport mapping, rasterization. The fragment's screen position and depth become available through `gl_FragCoord`.

## Fragment shader, step by step

### 1. Receive the vertex outputs

```glsl
in vec3 vNormal;
in vec3 vPosition;
in vec2 v_uv;
```

These match the vertex shader's outputs. Only the interpolated `vNormal` is used here. Position and UV are not written into the G-buffer by this shader.

### 2. Declare three color outputs

```glsl
layout(location = 0) out vec4 fragColor;
layout(location = 1) out vec4 gBufferDepth;
layout(location = 2) out vec4 gBufferNormal;
```

The application must provide compatible framebuffer attachments and enable the corresponding draw buffers. Locations identify shader outputs; they do not themselves create textures or make location 0 visible on the screen. The required number of attachments must also be supported by the device.

| Location | Value written | Purpose |
| --- | --- | --- |
| 0 | Encoded normal, opaque alpha | Diagnostic color. |
| 1 | Depth repeated in RGBA | Sampleable depth copy. |
| 2 | Encoded normal, opaque alpha | Surface normal for a later pass. |

### 3. Read and store depth

```glsl
float depth = gl_FragCoord.z;
gBufferDepth = vec4(depth, depth, depth, depth);
```

`gl_FragCoord.z` is window-space depth, normally in `[0, 1]` with the standard WebGL depth range. Under a conventional perspective projection it is non-linear with camera distance. The shader repeats it in all four channels; a later pass can read the red channel.

The output is a color-attachment copy of depth, separate from the depth attachment and depth test. Its format and precision affect the stored result.

### 4. Normalize the interpolated normal

```glsl
vec3 normalColor = normalize(vNormal);
```

Interpolation can shorten the normal, so this produces a unit direction for each fragment. A unit vector's components lie in `[-1, 1]`, but ordinary normalized color attachments store nonnegative values.

The source still labels this section `TODO`, but the normalization and encoding are present.

### 5. Encode the normal and write it to the G-buffer

```glsl
gBufferNormal = vec4(normalColor * 0.5 + 0.5, 1.0);
```

Each signed component is mapped from `[-1, 1]` to `[0, 1]`, with opaque alpha. For example:

| World normal | Encoded RGB |
| --- | --- |
| `(1, 0, 0)` | `(1, 0.5, 0.5)` |
| `(0, 1, 0)` | `(0.5, 1, 0.5)` |
| `(0, 0, -1)` | `(0.5, 0.5, 0)` |

To decode a sampled value later, reverse the mapping and normalize:

```glsl
vec3 normal = normalize(encodedNormal * 2.0 - 1.0);
```

Use compatible texture formats and sampling conventions so the encoded numerical values are not inadvertently changed by color-space conversion or blended with unrelated surfaces.

### 6. Display the same encoded normal

```glsl
fragColor = vec4(normalColor * 0.5 + 0.5, 1.0);
```

The display and normal attachments receive the same encoded RGB in this example. The colors visualize orientation, not light or material color: changes in the x, y, and z normal components alter red, green, and blue respectively.

## How this relates to later examples

[G-buffer 4](../gbuffer_4/CODE_EXPLANATION.md) demonstrates reconstructing world position from depth. [G-buffer 5](../gbuffer_5/CODE_EXPLANATION.md) decodes a normal and uses it for deferred lighting. Example 3 alone does not produce the albedo texture required by example 5; a complete deferred pipeline needs a geometry pass and framebuffer setup that provide all expected inputs.
