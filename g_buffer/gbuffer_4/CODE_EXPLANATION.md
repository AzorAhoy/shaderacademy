# Step-by-Step Explanation of the Selected Shaders

This document explains the vertex and fragment shaders in this G-buffer 4 example: [`vert.glsl`](./vert.glsl) and [`frag.glsl`](./frag.glsl).

## 1. G-buffer 4 vertex shader

File: [`vert.glsl`](./vert.glsl)

The vertex shader runs once for each mesh vertex. It prepares each vertex's position and attributes for rasterization and passes data to the fragment shader.

### Step 1: Declare the shader version and precision

```glsl
#version 300 es
precision highp float;
```

`#version 300 es` selects GLSL ES 3.00, the shader language version used by WebGL 2. `highp` requests high-precision floating-point calculations, which is useful for positions and matrices.

### Step 2: Receive mesh attributes

```glsl
in vec3 position;
in vec3 normal;
in vec2 uv;
```

These are per-vertex inputs supplied by the mesh:

- `position`: the vertex position in the mesh's local/object coordinate system.
- `normal`: the vertex surface normal, also in local/object space.
- `uv`: the vertex's 2D texture coordinate.

The application must connect the corresponding vertex buffers to these input attributes.

### Step 3: Receive transformation matrices

```glsl
uniform mat4 world;
uniform mat4 worldView;
uniform mat4 worldViewProjection;
```

Uniforms are shared by all vertices in a draw call. `world` transforms local coordinates to world coordinates. `worldViewProjection` transforms local coordinates all the way to clip space; it conventionally represents projection × view × world, in the matrix order expected by the renderer. `worldView` is declared but not used in this shader.

### Step 4: Declare values to pass to the fragment shader

```glsl
out vec3 vNormal;
out vec3 vPosition;
out vec2 v_uv;
```

These outputs are interpolated across each rendered triangle and become the matching `in` values in the fragment shader. The `v` prefix is a common convention for values varying across a primitive.

### Step 5: Compute the world-space position

```glsl
vec4 worldPos = world * vec4(position, 1.0);
vPosition = worldPos.xyz;
```

The local position is made homogeneous by adding `w = 1`, then multiplied by the world matrix. The resulting `xyz` is the world-space position. The fragment shader receives this as `vPosition`, although the current fragment shader does not use it.

### Step 6: Transform and normalize the normal

```glsl
vNormal = normalize(mat3(world) * normal);
```

The upper-left 3×3 portion of the world matrix transforms the normal's direction, and `normalize` makes its length one. This is sufficient for a rotation or uniform scale. If the world transform includes non-uniform scaling or shear, normals generally need the inverse-transpose normal matrix instead; otherwise their directions can be incorrect.

### Step 7: Forward the texture coordinates

```glsl
v_uv = uv;
```

The UV coordinates are passed through unchanged. They are available to the fragment shader, but the current G-buffer 4 fragment shader does not use them.

### Step 8: Compute the clip-space position

```glsl
gl_Position = worldViewProjection * vec4(position, 1.0);
```

`gl_Position` is the required vertex-shader output. The graphics pipeline uses this clip-space position for clipping and converts it into screen coordinates for rasterization.

## 2. G-buffer 4 fragment shader

File: [`frag.glsl`](./frag.glsl)

The fragment shader runs for each rasterized fragment. It writes the visible color and also stores depth in a second color attachment. It then reconstructs a world-space position from the fragment's screen coordinates and depth.

### Step 1: Receive interpolated values

```glsl
in vec3 vNormal;
in vec3 vPosition;
in vec2 v_uv;
```

These declarations match the vertex shader's outputs. The rasterizer interpolates them for each fragment. They are not used in the current `main` function; the shader instead obtains depth and screen coordinates from built-in fragment data.

### Step 2: Declare the uniforms

```glsl
uniform vec2 u_resolution;
uniform mat4 u_inverseViewProjection;
uniform float u_near;
uniform float u_far;
```

- `u_resolution` is the width and height, in pixels, of the viewport being rendered. The calculation also assumes the viewport starts at framebuffer coordinate `(0, 0)`; for a nonzero viewport origin, subtract that origin from `gl_FragCoord.xy` first.
- `u_inverseViewProjection` is the inverse of the camera's view-projection transform. Multiplying a clip-space position by it unprojects that position back into world space.
- `u_near` and `u_far` are declared but unused in this shader. The current reconstruction uses the depth-buffer value directly and does not linearize it using these planes.

### Step 3: Declare two fragment outputs

```glsl
layout(location = 0) out vec4 fragColor;
layout(location = 1) out vec4 gBufferDepth;
```

These are two simultaneous render targets (multiple render targets, or MRT). Location 0 receives the normal visible output. Location 1 receives a copy of the depth value for later G-buffer processing. The framebuffer must have compatible color attachments at both locations, and the draw configuration must enable them.

### Step 4: Read and store the depth-buffer value

```glsl
float depth = gl_FragCoord.z;
gBufferDepth = vec4(vec3(depth), 1.0);
```

`gl_FragCoord.z` is the fragment's window/depth-buffer value, conventionally in `[0, 1]`. It is non-linear with respect to distance from the camera under a perspective projection. The shader replicates it into the red, green, and blue channels and writes `1.0` to alpha. Later passes can sample a channel, usually red, to retrieve the stored depth.

This is the depth value written to a color attachment; it is separate from the depth test/depth buffer used by the graphics pipeline itself.

### Step 5: Convert pixel coordinates to UV coordinates

```glsl
vec2 uv = gl_FragCoord.xy / u_resolution;
```

`gl_FragCoord.xy` gives the fragment's window coordinates. With a viewport origin of `(0, 0)`, dividing by its width and height maps them to normalized screen coordinates, approximately `[0, 1]`. For a viewport with another origin, subtract that origin before division. Incorrect dimensions or origin distort the reconstructed horizontal and vertical positions.

### Step 6: Convert UV coordinates to normalized device coordinates

```glsl
vec2 ndc = uv * 2.0 - 1.0;
```

The vertex shader's clip-space coordinates are ultimately mapped to normalized device coordinates (NDC), whose x and y range is `[-1, 1]`. This reverses the screen mapping for x and y.

### Step 7: Convert depth to NDC z

```glsl
float ndcZ = depth * 2.0 - 1.0;
```

In the conventional OpenGL/WebGL depth mapping used here, depth in `[0, 1]` corresponds to NDC z in `[-1, 1]`. The expression reverses that mapping. It assumes the same conventional depth range and viewport setup were used when rendering.

### Step 8: Rebuild the clip-space position

```glsl
vec4 clipPos = vec4(ndc, ndcZ, 1.0);
```

The x, y, and z NDC coordinates are assembled into a homogeneous four-component position. The `w` value is set to one because this is the position to be unprojected.

### Step 9: Unproject to world space

```glsl
vec4 worldPos = u_inverseViewProjection * clipPos;
vec3 position = worldPos.xyz / worldPos.w;
```

Multiplication by the inverse view-projection matrix reverses the camera's projection and view transforms. The result is homogeneous, so dividing `xyz` by `w` performs the perspective divide and gives a world-space position.

The inverse matrix must correspond to the same camera and projection used to create the depth value. Incorrect matrix order, a stale camera matrix, mismatched viewport dimensions, or a different clip/depth convention will produce incorrect positions.

### Step 10: Encode part of the reconstructed position as a display color

```glsl
vec3 color = position * 0.5 + 0.5;
fragColor = vec4(ndc.xy, color.z, 1.0);
```

The first line remaps the world-space position from a signed range into a display-friendly range by applying `x * 0.5 + 0.5` to each component. This only produces meaningful color values when the chosen world-coordinate range is suitable; values can fall outside `[0, 1]`.

The final output does not use the whole `color` vector: red and green show the fragment's NDC x and y, while blue shows the remapped world-space z. Alpha is set to fully opaque. This is a diagnostic visualization, not a conventional material color.

## 3. How the two shaders work together

| Shader | Main purpose | Fragment outputs |
| --- | --- | --- |
| G-buffer 4 vertex shader | Transform vertices and provide attributes for fragment processing | Varyings: world normal, world position, and UV |
| G-buffer 4 fragment shader | Store depth, reconstruct world position, and visualize screen/world coordinates | Visible diagnostic color plus depth attachment |

The vertex shader transforms each mesh vertex and passes its varying values to the fragment shader. The fragment shader uses the rasterized screen coordinates and depth to reconstruct world-space position, writes a diagnostic color, and stores depth in the second render target.
