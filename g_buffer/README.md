# How a G-buffer Works

A **G-buffer**, short for *geometry buffer*, stores information about the visible surfaces in a scene in a set of screen-sized images. A later shader reads that information to calculate lighting. This is the foundation of **deferred shading**: record the surface first, then shade it.

This guide explains the idea and connects it to the five examples in this folder. For line-by-line explanations, follow the example links in the [learning path](#learning-path-through-the-examples).

## 1. Why separate geometry from lighting?

In a simple **forward-rendering** approach, a material shader processes a fragment and calculates its lighting as that geometry is drawn. In deferred shading, the renderer splits the work:

1. A **geometry pass** draws the scene and records information about the visible surface at each pixel.
2. A **lighting pass** reads those stored values and calculates how lights affect that surface.

The G-buffer is the collection of stored values between those two passes. It is not necessarily a single image: it commonly consists of several textures or other framebuffer attachments.

Deferred shading can make it convenient to apply many lights to the recorded surfaces without rerunning the material's geometry shader for every light. It also costs memory and bandwidth, and features such as transparency and multisampling need extra care. It is a design trade-off, not automatically faster for every scene.

## 2. The big picture

```text
Mesh vertices + material + camera
              |
              v
       GEOMETRY PASS
  transform and rasterize geometry
  test depth; record surface data
              |
              v
  +---------------------------------+
  |             G-buffer            |
  |  depth | normal | albedo | ...  |
  +---------------------------------+
              |
              v
       LIGHTING PASS
  read each pixel's surface data
  reconstruct position, evaluate lights
              |
              v
       final shaded image
```

Each G-buffer sample describes a visible surface at a corresponding screen location. Depth testing during the geometry pass normally selects the nearest opaque surface, provided the application configures the depth attachment and depth test appropriately. A basic G-buffer does not retain every overlapping transparent layer.

## 3. What is stored?

The exact layout depends on the renderer. The lighting example in this repository expects:

| Input | What it represents | How the lighting shader uses it |
| --- | --- | --- |
| Depth | The visible fragment's window-space depth. | Reconstructs its world-space position. |
| Normal | The surface's world-space direction, encoded as RGB. | Determines whether the surface faces a light. |
| Albedo | The surface's base color, plus an alpha marker. | Colors the light; alpha zero identifies an empty pixel. |

Other renderers may store material properties such as roughness or metallic, or store position directly instead of reconstructing it. Each extra attachment has a memory and bandwidth cost.

The alpha convention here is specific to the [lighting shader](./gbuffer_5/frag.glsl). It is not a universal G-buffer rule: its geometry pass must clear albedo alpha to zero and write nonzero alpha for geometry.

## 4. Step by step: prepare the geometry pass

The application, not the GLSL output declarations alone, must:

1. Create a framebuffer with compatible color attachments for the chosen G-buffer layout and a depth attachment for depth testing.
2. Check that the device supports the required number and formats of attachments and that the framebuffer is complete.
3. Configure the draw buffers so each fragment output location maps to the intended color attachment.
4. Set the viewport and clear the attachments and depth buffer to appropriate values. In example 5's convention, clear albedo alpha to zero.
5. Enable and configure depth testing for the scene, bind the geometry shader and mesh, supply matrices and material data, and draw the opaque geometry.

Writing to several color attachments in one fragment shader is called **multiple render targets** (MRT). For example, [G-buffer 3](./gbuffer_3/frag.glsl) declares outputs at locations 0, 1, and 2. A location identifies an output; the framebuffer and draw-buffer configuration determine where it goes. Location 0 is not automatically the screen when drawing to an off-screen framebuffer.

The examples show shader concepts, not a complete application-side framebuffer setup.

## 5. Step by step: transform and rasterize geometry

For each vertex, the [G-buffer 3 vertex shader](./gbuffer_3/vert.glsl) performs these operations:

```glsl
vec4 worldPos = world * vec4(position, 1.0);
vPosition = worldPos.xyz;
vNormal = normalize(mat3(world) * normal);
v_uv = uv;
gl_Position = worldViewProjection * vec4(position, 1.0);
```

1. `world` transforms the object-space position into world space.
2. The shader transforms the surface normal into world space.
3. UV coordinates are passed through for potential material texture lookup.
4. `worldViewProjection` transforms the vertex into clip space for clipping and rasterization.
5. The rasterizer generates fragments and interpolates the vertex outputs across each triangle.

The simple `mat3(world)` normal transform works for rotations and uniform scaling. With non-uniform scaling or shear, a normal generally needs the inverse transpose of the world matrix's linear part. The fragment shader normalizes the interpolated normal again because interpolation can change its length.

In the current G-buffer 3 fragment shader, only the normal varying is used; world position and UV are not stored there.

## 6. Step by step: record depth

The fragment shader in [G-buffer 2](./gbuffer_2/frag.glsl) reads:

```glsl
float depth = gl_FragCoord.z;
gBufferDepth = vec4(depth, depth, depth, depth);
```

`gl_FragCoord.z` is the fragment's **window-space depth**. Under the standard WebGL depth range it is in `[0, 1]`; with a conventional perspective projection it is non-linear with distance from the camera.

Here, the shader copies depth into every channel of a **color attachment**. The lighting pass can later read the red channel. This copy is separate from the depth attachment used for depth testing. Its precision depends on the chosen color format; a renderer may instead sample a suitable depth texture directly.

The visible output of example 2 is `1.0 - depth`, a grayscale visualization. It is not the same value as the depth copied into the second attachment. For example, a stored depth of `0.2` displays as gray `0.8`; a stored depth of `0.9` displays as gray `0.1`.

## 7. Step by step: record and recover the normal

The [G-buffer 3 fragment shader](./gbuffer_3/frag.glsl) normalizes and encodes the interpolated normal:

```glsl
vec3 normalColor = normalize(vNormal);
gBufferNormal = vec4(normalColor * 0.5 + 0.5, 1.0);
```

A unit normal can have negative components, so the expression maps each component from `[-1, 1]` to `[0, 1]` for storage in a normalized color texture:

| World-space normal | Stored RGB |
| --- | --- |
| `(1, 0, 0)` | `(1, 0.5, 0.5)` |
| `(0, 1, 0)` | `(0.5, 1, 0.5)` |
| `(0, 0, -1)` | `(0.5, 0.5, 0)` |

The lighting pass reverses this mapping:

```glsl
vec3 normal = normalize(texture(gBufferNormal, vUV).rgb * 2.0 - 1.0);
```

For example, `(0.5, 1, 0.5)` decodes to `(0, 1, 0)`. Normalize after decoding to compensate for interpolation or storage precision. The normal must be in the same coordinate space as the positions and lights; example 5 expects **world space**.

Normal and depth textures contain numerical data, not display colors. Choose compatible formats and sampling settings; unintended color-space conversion, blending, or filtering across unrelated surfaces can change the stored values.

## 8. Step by step: reconstruct position from depth

Storing full world position is possible, but this example reconstructs it from screen position and depth instead. [G-buffer 4](./gbuffer_4/frag.glsl) shows the process:

```glsl
vec2 uv = gl_FragCoord.xy / u_resolution;
vec2 ndc = uv * 2.0 - 1.0;
float ndcZ = depth * 2.0 - 1.0;
vec4 clipPos = vec4(ndc, ndcZ, 1.0);
vec4 worldPos = u_inverseViewProjection * clipPos;
vec3 position = worldPos.xyz / worldPos.w;
```

1. Divide the fragment's window coordinates by the viewport dimensions to get screen UV. This code assumes a viewport origin of `(0, 0)`; otherwise subtract the origin first.
2. Map UV from `[0, 1]` to normalized device coordinates (NDC) in `[-1, 1]`.
3. Reverse the standard WebGL depth mapping: `ndcZ = depth * 2 - 1`.
4. Form a homogeneous representation of the NDC point with `w = 1`. Although the variable is named `clipPos`, it is not the original clip-space vector: its original `w` is not known.
5. Multiply by the inverse of the same view-projection matrix used for the geometry pass.
6. Divide the resulting `xyz` by `w` to obtain a Cartesian world-space position.

For a center screen coordinate `(0.5, 0.5)` and depth `0.75`, the constructed NDC point is `(0, 0, 0.5)`. The actual world position still depends on the camera matrix.

[G-buffer 5](./gbuffer_5/frag.glsl) follows the same reconstruction, using its full-screen `vUV` and sampled depth. The matrix, viewport/UV orientation, projection, and depth convention must match the geometry pass. Example 4 visualizes NDC x/y and reconstructed world z; it does not display all three world-position components.

## 9. Step by step: run the lighting pass

The application renders a screen-covering primitive using the lighting shader and binds the G-buffer textures. Each lighting fragment samples the corresponding surface:

1. **Read albedo.** If `albedo.a == 0.0`, example 5 writes a dark background and returns. This depends on the geometry-pass clear/write convention.
2. **Read depth and reconstruct position.** The shader maps screen UV and sampled depth to NDC, applies `u_inverseViewProjection`, and divides by `w`.
3. **Read and decode the normal.** The encoded RGB becomes a normalized world-space normal.
4. **Start with ambient light.** `albedo.rgb * 0.04` provides a small constant baseline.
5. **Add each point light.** For each light, find the direction and distance, compute the diffuse response, attenuate by distance, and add the colored contribution.
6. **Write the final color.** Example 5 outputs the accumulated RGB with opaque alpha.

The light calculation is:

```glsl
vec3 toLight = LIGHT_POSITIONS[i] - position;
float dist = length(toLight);
float diff = max(dot(normal, toLight / dist), 0.0);
float attenuation = 1.0 / (1.0 + 0.03 * dist * dist);
color += albedo.rgb * LIGHT_COLORS[i] * diff * attenuation;
```

If a unit normal points directly at a light, their dot product is `1`; if perpendicular, it is `0`; if facing away, `max` clamps the negative result to `0`. At distance `10`, attenuation is `1 / (1 + 0.03 * 100) = 0.25`. The source assumes the distance is not zero, since `toLight / dist` would otherwise be undefined.

This example uses three fixed point lights and a simple diffuse model. It does not calculate shadows, specular highlights, or physically based material response.

## 10. Follow one pixel through the pipeline

Suppose a geometry pass records a visible surface at a pixel:

- Albedo: `(0.8, 0.4, 0.2, 1.0)`.
- Depth: `0.75`.
- Encoded world normal: `(0.5, 1.0, 0.5)`, which decodes to `(0, 1, 0)`.

The lighting pass sees alpha `1.0`, so it proceeds. It reconstructs a world position from that pixel's UV, depth, and inverse camera matrix. Its initial ambient RGB is `0.04 * (0.8, 0.4, 0.2) = (0.032, 0.016, 0.008)`. It then adds each light's diffuse contribution using the reconstructed position and decoded normal.

The depth value alone is not enough to determine a world position: the pixel's screen coordinates and the correct camera transform are also required.

## Learning path through the examples

These are teaching examples, not five plug-and-play stages of one complete renderer. In particular, example 3 stores depth and normals but does **not** create the albedo texture required by example 5; a complete application needs a compatible geometry pass, framebuffer setup, and screen-pass vertex shader.

| Example | What it teaches | Detailed guide |
| --- | --- | --- |
| 1 | Map world position to a diagnostic RGB color; one output. | [Position visualization](./gbuffer_1/CODE_EXPLANATION.md) |
| 2 | Copy window depth to a color attachment and display inverse depth. | [Depth](./gbuffer_2/CODE_EXPLANATION.md) |
| 3 | Write depth and encoded world normals using MRT. | [Depth and normals](./gbuffer_3/CODE_EXPLANATION.md) |
| 4 | Reconstruct world position from screen coordinates and depth. | [Position reconstruction](./gbuffer_4/CODE_EXPLANATION.md) |
| 5 | Read depth, normal, and albedo, then apply deferred lighting. | [Deferred lighting](./gbuffer_5/CODE_EXPLANATION.md) |

## Troubleshooting

- **Everything is dark in the depth preview:** perspective depth is non-linear and often clustered near 1. Check the camera range and the inverted visualization before assuming the buffer is empty.
- **Normals look wrong:** verify the normal matrix, world-space convention, encoding/decoding, attachment format, and sampling settings.
- **Lighting moves or stretches incorrectly:** verify the inverse view-projection matrix, viewport origin and dimensions, UV orientation, depth range, and depth texture precision.
- **The whole image is background:** confirm that albedo alpha is cleared to zero and written nonzero where geometry is drawn, and that the lighting pass samples the correct texture.
- **A G-buffer output is missing:** check framebuffer completeness, attachment formats, output locations, draw buffers, and hardware limits.
