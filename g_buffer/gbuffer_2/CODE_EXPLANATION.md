# G-buffer 2: Writing and Visualizing Depth

This example uses a [vertex shader](./vert.glsl) and a [fragment shader](./frag.glsl). The vertex shader places the mesh on screen; the fragment shader reads each fragment's window-space depth, writes it to a second color attachment, and displays its inverse as grayscale.

## The rendering flow

1. The application supplies mesh data, matrices, and a framebuffer configured for the shader's outputs.
2. The vertex shader transforms the mesh and passes attributes to the rasterizer.
3. The fragment shader reads `gl_FragCoord.z`, writes a depth copy to output 1, and writes a grayscale visualization to output 0.
4. Depth testing and the actual depth buffer are configured separately by the application; the extra color attachment is a sampleable copy, not the depth buffer itself.

## Vertex shader, step by step

### 1. Choose GLSL version and precision

```glsl
#version 300 es
precision highp float;
```

The shader uses GLSL ES 3.00, as in WebGL 2. `highp` requests high-precision floating-point calculations, important when transforming positions.

### 2. Receive vertex attributes

```glsl
in vec3 position;
in vec3 normal;
in vec2 uv;
```

The mesh supplies a local/object-space position, a local-space normal, and a UV coordinate for each vertex. The application must bind the vertex data to the corresponding inputs.

### 3. Receive matrices

```glsl
uniform mat4 world;
uniform mat4 worldView;
uniform mat4 worldViewProjection;
```

`world` maps object space to world space. `worldViewProjection` maps object space to clip space and normally combines projection, view, and world in that order. `worldView` is declared but not used.

### 4. Declare interpolated outputs

```glsl
out vec3 vNormal;
out vec3 vPosition;
out vec2 v_uv;
```

These values are passed to corresponding fragment inputs and normally interpolated perspective-correctly across the triangle. In this example, the fragment shader declares all three but does not use any of them to compute depth or color.

### 5. Transform and pass the world position

```glsl
vec4 worldPos = world * vec4(position, 1.0);
vPosition = worldPos.xyz;
```

The `1.0` makes the input a homogeneous point, so the world matrix can apply translation. `vPosition` receives the resulting world-space `xyz`. It is available for other effects but is unused by this fragment shader.

### 6. Transform the normal and pass the UV

```glsl
vNormal = normalize(mat3(world) * normal);
v_uv = uv;
```

The 3-by-3 world transform changes the normal's direction and `normalize` makes it unit length. This is suitable for rotations and uniform scaling; non-uniform scaling or shear generally requires the inverse-transpose normal matrix. The UV is copied unchanged. Neither varying affects this example's fragment output.

### 7. Output the clip-space vertex

```glsl
gl_Position = worldViewProjection * vec4(position, 1.0);
```

The graphics pipeline clips the resulting primitive, performs the perspective divide, maps the result to the viewport, and rasterizes it. Fragment depth is derived from this pipeline; the shader does not calculate it from `vPosition`.

## Fragment shader, step by step

### 1. Declare the inputs and outputs

```glsl
in vec3 vNormal;
in vec3 vPosition;
in vec2 v_uv;

layout(location = 0) out vec4 fragColor;
layout(location = 1) out vec4 gBufferDepth;
```

The inputs match the vertex outputs but are unused in `main`. The two output locations are separate fragment color outputs: location 0 is the visualization, and location 1 is the depth copy. To retain both, the application must attach compatible images and enable the appropriate draw buffers for its framebuffer; the declarations alone do not configure it. Location 0 is not automatically visible on screen when rendering into an off-screen framebuffer.

### 2. Read the fragment's depth

```glsl
float depth = gl_FragCoord.z;
```

`gl_FragCoord.z` is the fragment's window-space depth. With the standard WebGL depth range it is in `[0, 1]`: near maps toward 0 and far toward 1. Under a conventional perspective projection it is **not linear in camera distance**. With an orthographic projection the relationship is different. Depth range, projection, and any depth-writing overrides must be consistent when interpreting the value.

The source's `TODO` is an exercise label; the shown line already reads the depth value.

### 3. Copy depth into the G-buffer output

```glsl
gBufferDepth = vec4(depth, depth, depth, depth);
```

All four channels receive the same depth. A later pass can sample the red channel, for example. This writes to a color attachment, not to the depth attachment used for depth testing. The attachment's format and precision affect how accurately the depth is preserved.

### 4. Show the inverse depth as grayscale

```glsl
fragColor = vec4(1.0 - depth, 1.0 - depth, 1.0 - depth, 1.0);
```

The same value in red, green, and blue gives grayscale; alpha is opaque. For example, depth `0.2` displays as `(0.8, 0.8, 0.8)`, while depth `0.9` displays as `(0.1, 0.1, 0.1)`. With the standard depth convention, nearer fragments therefore tend to appear brighter.

Perspective depth values often cluster near 1 for much of the visible range, so much of the image may look dark. This is expected and does not mean depth is linear or missing.

## Important distinctions

| Value | Meaning |
| --- | --- |
| `gl_FragCoord.z` | The current fragment's window-space depth. |
| `gBufferDepth` | A copy of that number written into a color attachment. |
| `fragColor` | An inverted grayscale visualization, not the stored depth copy. |
| Depth attachment | The separate framebuffer attachment used by the depth test, if configured. |

[G-buffer 3](../gbuffer_3/CODE_EXPLANATION.md) adds an encoded world-space normal alongside depth.
