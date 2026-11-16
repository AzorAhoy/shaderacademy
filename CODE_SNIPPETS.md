# Common Code Snippets and Usage Guide

This guide collects reusable patterns found in the project's GLSL shaders and procedural-mesh code. Each example includes its purpose, how to use it, and important assumptions. Snippets are representative; adapt names and data sources to the shader and renderer that use them.

For definitions and formulas for the terms used below, see the project [glossary](./GLOSSARY.md).
For axis directions, mesh UV layouts, and an interactive demonstration, see
[3D axes and UV coordinate conventions](./COORDINATE_CONVENTIONS.md).
For transformation math and a visual explorer, see the
[transformation guide](./transforms/README.md).
In the notebook, links to examples not listed in its public-content allowlist
remain repository-relative; open those files in the repository instead.

## Browse by topic

### GLSL basics and textures

- [1. Common GLSL built-in functions](#snippet-1)
- [4. Sampling a 2D texture](#snippet-4)

### Transformations and deformation

- [2. Standard vertex transformation](#snippet-2)
- [3. Instanced vertex transformation](#snippet-3)
- [20. Rotation matrices and a local pivot](#snippet-20)
- [23. Scale geometry around a local pivot](#snippet-23)
- [21. Taper over a local coordinate range](#snippet-21)
- [22. Twist along a local axis](#snippet-22)

### G-buffer and depth

- [5. Writing multiple render targets](#snippet-5)
- [6. Encoding and decoding normals](#snippet-6)
- [7. Reconstructing world position from depth](#snippet-7)

### Lighting and color

- [8. Lambert diffuse point-light contribution](#snippet-8)
- [9. Schlick Fresnel and reflection blending](#snippet-9)
- [10. PBR Cook-Torrance specular term](#snippet-10)
- [11. Reusable Cook-Torrance helper functions](#snippet-11)
- [12. Tone mapping and gamma correction](#snippet-12)

### Texture and screen effects

- [13. POM height sampling and filtered color lookup](#snippet-13)
- [15. Mouse-centered ripple and falloff](#snippet-15)
- [16. Animated screen-space scanlines](#snippet-16)
- [18. Red-channel threshold transition](#snippet-18)

### Particles and procedural geometry

- [17. Deterministic particle targets and animation](#snippet-17)
- [14. Procedural indexed quad construction](#snippet-14)
- [19. Lathe surface and profile normal](#snippet-19)

Finish with the [general integration checklist](#snippet-checklist). Snippet
numbers remain unchanged so existing references are easy to recognize.

<a id="snippet-1"></a>

## 1. Common GLSL built-in functions

These are **GLSL shader functions**, not CPU-side OpenGL/WebGL API calls. Examples below target the project's GLSL ES 3.00 shaders. Unless a complete shader is shown, put calculation snippets inside `main` or another function and supply the named inputs.

Many functions operate component-wise on vectors: for example, `clamp(vec3Color, 0.0, 1.0)` limits each RGB channel separately.

### `mix` - blend between values

**Formula:** `mix(a, b, t) = a * (1 - t) + b * t`.

```glsl
vec3 cold = vec3(0.1, 0.3, 0.9);
vec3 warm = vec3(1.0, 0.5, 0.1);
vec3 color = mix(cold, warm, clamp(blendAmount, 0.0, 1.0));
```

Use for color gradients, material blends, and interpolation between ray-march samples. `t = 0` returns `a`; `t = 1` returns `b`. `mix` does **not** clamp `t`: values outside `[0, 1]` extrapolate. The project uses it for sky colors and Fresnel blending in [`light_6/frag.glsl`](./materials/light_6/frag.glsl).

### `smoothstep` - create a soft transition

**Formula:** For `edge0 < edge1`, let `t = clamp((x - edge0) / (edge1 - edge0), 0, 1)`. The result is `t * t * (3 - 2 * t)`.

```glsl
float skyMask = smoothstep(-0.02, 0.02, direction.y);
vec3 color = mix(groundColor, skyColor, skyMask);
```

Below the first edge the result is 0; above the second it is 1. Between them it smoothly transitions, with a value of 0.5 at the midpoint. Use it for soft masks, horizons, fades, and remapping height values.

**Pitfall:** Results are undefined when `edge0 >= edge1`. To invert a mask, use `1.0 - smoothstep(low, high, x)`, not reversed edges. The project uses soft sky transitions and height remapping in [`light_6/frag.glsl`](./materials/light_6/frag.glsl) and [`parallax_2/frag.glsl`](./materials/parallax_2/frag.glsl).

### `step` - create a hard threshold

**Formula:** `step(edge, x)` is 0 if `x < edge`, otherwise 1.

```glsl
float metallic = step(0.0, worldPosition.x - worldPosition.z);
vec3 albedo = mix(plasticColor, metalColor, metallic);
```

Use for binary material selection and sharp masks. Unlike `smoothstep`, it has no transition band. At the threshold itself it returns 1. This material split appears in [`light_7/frag.glsl`](./materials/light_7/frag.glsl).

### `clamp`, `min`, and `max` - limit values

```glsl
float roughness = clamp(inputRoughness, 0.04, 1.0);
float diffuse = max(dot(normal, lightDir), 0.0);
float cappedIntensity = min(intensity, 10.0);
```

- `clamp(x, low, high)` is `min(max(x, low), high)`; keep `low <= high`.
- `max(a, b)` returns the larger value, commonly used to remove negative diffuse illumination.
- `min(a, b)` returns the smaller value, useful for upper limits.

Clamping a denominator can prevent division by zero, but choose the bound according to the calculation rather than hiding invalid inputs. See the guarded specular denominator in [`light_7/frag.glsl`](./materials/light_7/frag.glsl).

### `dot`, `length`, `distance`, and `normalize` - vector calculations

```glsl
vec3 toLight = lightPosition - worldPosition;
float lightDistance = length(toLight);
vec3 lightDir = normalize(toLight);
float diffuse = max(dot(normalize(surfaceNormal), lightDir), 0.0);
```

**Formulas:**

- `dot(a, b) = a.x*b.x + a.y*b.y + a.z*b.z` for 3D vectors.
- `length(v) = sqrt(dot(v, v))`.
- `distance(a, b) = length(a - b)`.
- `normalize(v) = v / length(v)` for a nonzero vector.

Use for lighting angles, distances, and unit directions, as in [`gbuffer_5/frag.glsl`](./g_buffer/gbuffer_5/frag.glsl). With unit vectors, the dot product equals the cosine of their angle.

**Preconditions:** `toLight` and `surfaceNormal` must be nonzero. A zero-length vector has no defined unit direction; handle that case according to your application's lighting policy before normalizing it.

### `cross` - find a perpendicular direction

**Formula:** `cross(a, b) = (a.y*b.z-a.z*b.y, a.z*b.x-a.x*b.z, a.x*b.y-a.y*b.x)`.

```glsl
vec3 edge1 = p1 - p0;
vec3 edge2 = p2 - p0;
vec3 faceNormal = normalize(cross(edge1, edge2));
```

Use to derive a triangle normal or construct a surface basis. The triangle must be nondegenerate: collinear or repeated points yield a zero cross product that cannot be normalized.

Swapping the edges reverses the normal: `cross(a, b) = -cross(b, a)`. This explains the winding-order diagrams in the [glossary](./GLOSSARY.md#face-winding). This is an additional reusable example; the current cube builder supplies face normals explicitly.

### `reflect` - reflect an incident direction

**Formula:** `reflect(I, N) = I - 2 * dot(N, I) * N`, with unit-length `N`.

```glsl
vec3 N = normalize(surfaceNormal);
vec3 V = normalize(cameraPosition - worldPosition);
vec3 reflectedDirection = reflect(-V, N);
```

Use for environment reflections. `I` points **toward** the surface; the surface-to-camera direction `V` must therefore be negated. Keep `N` and `V` in the same coordinate space. See [`light_6/frag.glsl`](./materials/light_6/frag.glsl).

### `pow` and `sqrt` - powers and roots

```glsl
float cosTheta = clamp(dot(normal, viewDir), 0.0, 1.0);
float fresnelWeight = pow(1.0 - cosTheta, 5.0);
vec3 displayColor = pow(linearColor, vec3(1.0 / 2.2));
float root = sqrt(nonnegativeValue);
```

`pow(x, y)` calculates a power; `sqrt(x)` calculates the square root. In GLSL, a negative base for `pow` is undefined, even when the exponent happens to be an integer. Also avoid `pow(0, y)` for `y <= 0`, and keep `sqrt` inputs nonnegative.

Use powers for Fresnel, highlight shaping, and the project's approximate gamma transform. Perform display conversion only once; see section 12 and [`light_7/frag.glsl`](./materials/light_7/frag.glsl).

### `abs`, `floor`, `fract`, and `mod` - patterns and repetition

**Formulas:** `fract(x) = x - floor(x)`; `mod(x, y) = x - y * floor(x / y)` for a nonzero divisor.

```glsl
vec2 tiledUV = fract(uv * 4.0);
vec2 cell = floor(uv * 4.0);
float checker = mod(cell.x + cell.y, 2.0);
vec3 checkerColor = mix(vec3(0.15), vec3(0.9), checker);
float mirroredDistance = abs(worldPosition.x);
```

- `abs` removes a number's sign.
- `floor` rounds down, including toward more-negative values.
- `fract` returns the fractional part in `[0, 1)`.
- `mod` supports repeating patterns; its behavior with negative inputs follows the formula above, not necessarily a language's remainder operator.

These are additional pattern-building examples that can be used with the project's UV-based materials. `fract` introduces seams in UV derivatives. For ordinary image repetition, prefer renderer-configured texture wrapping where possible; use explicit gradients if a procedural wrap needs stable mip selection.

### `sin` - periodic motion and patterns

```glsl
float phase = distanceFromCenter * frequency - time * speed;
float wave = sin(phase) * amplitude;
```

`sin` takes radians and returns a value in `[-1, 1]`. In this example,
`frequency` is radians per distance unit, `speed` is radians per time unit,
and `amplitude` scales the output. For positive frequency and speed, a fixed
phase moves outward at `speed / frequency` distance units per time unit.
The [interactive ripple shader](./interactive/interact_5/frag.glsl) adds three
such waves; the [scanline shader](./uv/uv_4/frag.glsl) uses a sine of screen Y
and time to produce horizontal bands.

### `texture`, `textureLod`, and `textureGrad` - texture lookup

```glsl
vec4 baseColor = texture(u_texture, uv);
float height = textureLod(u_heightMap, uv, 0.0).r;
vec4 displacedColor = textureGrad(
    u_texture, displacedUV, dFdx(uv), dFdy(uv)
);
```

- `texture` performs a normal lookup; fragment shaders generally select a mip level using implicit derivatives.
- `textureLod` explicitly chooses a mip level; 0 selects the base level.
- `textureGrad` takes explicit UV derivatives to control mip selection/filtering.

Capture gradients in uniform control flow before any per-fragment early exit or divergent loop when they are needed afterward. Explicit LOD makes mip selection deterministic; it does not automatically eliminate aliasing. See the project's height search in [`parallax_2/frag.glsl`](./materials/parallax_2/frag.glsl).

### `dFdx`, `dFdy`, and `fwidth` - screen-space derivatives

**Formula:** `fwidth(x) = abs(dFdx(x)) + abs(dFdy(x))`.

```glsl
float value = uv.x;
float halfWidth = max(fwidth(value), 0.00001);
float softEdge = smoothstep(
    0.5 - halfWidth, 0.5 + halfWidth, value
);
```

This additional example creates a derivative-scaled transition around `uv.x = 0.5`, useful for anti-aliased procedural boundaries. `dFdx` and `dFdy` measure variation across neighboring fragments, not mesh vertices.

These functions belong in fragment shaders in this GLSL ES version. Evaluate them in uniform control flow; derivatives inside non-uniform branches or after divergent exits may be undefined. The parallax example uses UV derivatives for `textureGrad` ([`parallax_2/frag.glsl`](./materials/parallax_2/frag.glsl)).

<a id="snippet-2"></a>

## 2. Standard vertex transformation

**Use for:** Transforming a mesh's local-space vertex into world and clip space. This pattern appears in several material and G-buffer vertex shaders, including [`gbuffer_1/vert.glsl`](./g_buffer/gbuffer_1/vert.glsl) and [`light_7/vert.glsl`](./materials/light_7/vert.glsl).

```glsl
vec4 worldPos = world * vec4(position, 1.0);
vPosition = worldPos.xyz;
vNormal = normalize(mat3(world) * normal);
v_uv = uv;
gl_Position = worldViewProjection * vec4(position, 1.0);
```

### How to use it

1. Provide local-space `position`, `normal`, and `uv` attributes.
2. Set `world` and `worldViewProjection` from the renderer for the current object and camera.
3. Declare matching `out` values in the vertex shader and `in` values in the fragment shader.
4. Use `vPosition`, `vNormal`, and `v_uv` in the fragment shader for world-space shading, surface orientation, and texture sampling.

### Important notes

- Positions are represented as `vec4(position, 1.0)` so translation applies.
- The `worldViewProjection` matrix should apply the world, view, and projection transforms in the multiplication order expected by the renderer.
- `mat3(world) * normal` is suitable for rotations and uniform scales. For non-uniform scale or shear, use an inverse-transpose normal matrix.
- The fragment shader interpolates varyings across a triangle.

<a id="snippet-3"></a>

## 3. Instanced vertex transformation

**Use for:** Rendering multiple copies of a mesh with a separate world matrix per instance. The project demonstrates this in [`procedural_mesh_7/vert.glsl`](./procedural_mesh_basics/procedural_mesh_7/vert.glsl).

```glsl
in vec4 world0;
in vec4 world1;
in vec4 world2;
in vec4 world3;

uniform mat4 view;
uniform mat4 projection;

void main() {
    mat4 instanceWorld = mat4(world0, world1, world2, world3);
    vec4 worldPos = instanceWorld * vec4(position, 1.0);
    gl_Position = projection * view * worldPos;
}
```

### How to use it

1. Pack each instance matrix into four `vec4` attributes.
2. Configure the renderer so those attributes advance once per instance, not once per vertex.
3. Supply the camera's `view` and `projection` matrices.
4. Apply the instance transform before the camera transforms.

The renderer must bind all four matrix columns consistently. A transposed or incorrectly ordered matrix will move or distort instances.

<a id="snippet-4"></a>

## 4. Sampling a 2D texture

**Use for:** Applying a texture to a mesh. The simplest form appears in [`procedural_mesh_7/frag.glsl`](./procedural_mesh_basics/procedural_mesh_7/frag.glsl).

```glsl
in vec2 v_uv;
uniform sampler2D u_texture;
out vec4 fragColor;

void main() {
    fragColor = texture(u_texture, v_uv);
}
```

### How to use it

1. Put UV coordinates in the mesh.
2. Pass UVs from the vertex shader to the fragment shader using matching varying declarations.
3. Bind a 2D texture to a texture unit and assign that unit to `u_texture`.
4. Sample with `texture` at each fragment's interpolated UV.

Texture filtering, wrapping, mipmaps, and color-space interpretation are configured by the application and texture setup; they are not specified by this code.

<a id="snippet-5"></a>

## 5. Writing multiple render targets (MRT)

**Use for:** Storing more than one per-fragment result in one geometry pass. G-buffer shaders use this approach for color, depth, and normals, for example [`gbuffer_3/frag.glsl`](./g_buffer/gbuffer_3/frag.glsl) and [`gbuffer_4/frag.glsl`](./g_buffer/gbuffer_4/frag.glsl).

```glsl
layout(location = 0) out vec4 fragColor;
layout(location = 1) out vec4 gBufferDepth;

void main() {
    float depth = gl_FragCoord.z;
    gBufferDepth = vec4(depth, depth, depth, 1.0);
    fragColor = vec4(vec3(1.0 - depth), 1.0);
}
```

### How to use it

1. Attach compatible color textures to the framebuffer at locations 0 and 1.
2. Ensure the renderer's draw-buffer configuration enables those attachments.
3. Write each shader output to the matching `layout(location = ...)`.
4. In a later pass, bind the textures as samplers and read the stored channels.

`gl_FragCoord.z` is the current fragment's depth value, conventionally in `[0, 1]`, and is generally non-linear under perspective projection. A color attachment storing this value is distinct from the depth attachment used for depth testing. If alpha is also used as a coverage marker, define and preserve a consistent clear/write convention.

<a id="snippet-6"></a>

## 6. Encoding and decoding normals

**Use for:** Saving signed normal components in a normalized color texture and recovering them later. Encoding appears in [`gbuffer_3/frag.glsl`](./g_buffer/gbuffer_3/frag.glsl); decoding is shown in [`gbuffer_5/frag.glsl`](./g_buffer/gbuffer_5/frag.glsl).

```glsl
// Store a normalized normal in [0, 1].
vec3 normalEncoded = normalize(normal) * 0.5 + 0.5;

// Recover a signed, unit-length normal.
vec3 normalDecoded = normalize(normalEncoded * 2.0 - 1.0);
```

### How to use it

1. Normalize the normal before encoding it.
2. Store the encoded value in an RGB texture.
3. In the later pass, sample the same RGB channels and apply the inverse mapping.
4. Normalize again to compensate for texture precision and interpolation.

Both passes must agree on the normal's coordinate space. If lighting uses world-space positions and light positions, decode or transform the normal into world space as well.

<a id="snippet-7"></a>

## 7. Reconstructing world position from depth

**Use for:** Recovering a world-space point in a screen-space/deferred pass using a sampled depth texture. The pattern is used in [`gbuffer_5/frag.glsl`](./g_buffer/gbuffer_5/frag.glsl), building on [`gbuffer_4/frag.glsl`](./g_buffer/gbuffer_4/frag.glsl).

```glsl
vec2 ndcXY = vUV * 2.0 - 1.0;
float depth = texture(gBufferDepth, vUV).r;
float ndcZ = depth * 2.0 - 1.0;

vec4 clipPos = vec4(ndcXY, ndcZ, 1.0);
vec4 worldPos = u_inverseViewProjection * clipPos;
vec3 position = worldPos.xyz / worldPos.w;
```

### How to use it

1. Render depth with the same camera and projection used by the later pass.
2. Use UVs that address the corresponding texel in the depth texture.
3. Convert screen UV and sampled depth into the expected NDC range.
4. Supply the inverse of the matching view-projection matrix.
5. Divide by the resulting homogeneous `w` to obtain Cartesian world coordinates.

This version assumes the conventional OpenGL/WebGL mapping from depth `[0, 1]` to NDC z `[-1, 1]`. It also assumes the UV orientation matches the render target and the inverse matrix was built with the same camera state. Viewport size, coordinate origin, depth convention, and matrix order must remain consistent.

<a id="snippet-8"></a>

## 8. Lambert diffuse point-light contribution

**Use for:** A simple diffuse response from a point light with distance falloff. The project uses this pattern in [`gbuffer_5/frag.glsl`](./g_buffer/gbuffer_5/frag.glsl), and a related dot-product form in [`light_6/frag.glsl`](./materials/light_6/frag.glsl).

```glsl
vec3 toLight = lightPosition - position;
float dist = length(toLight);
vec3 lightDir = toLight / dist;

float diffuse = max(dot(normal, lightDir), 0.0);
float attenuation = 1.0 / (1.0 + 0.03 * dist * dist);

color += albedo * lightColor * diffuse * attenuation;
```

### How to use it

1. Use positions and normals in the same coordinate space.
2. Normalize the normal and light direction.
3. Clamp the dot product at zero so a surface facing away receives no diffuse contribution from that light.
4. Multiply by albedo, light color, and an attenuation model appropriate for the scene.

The example assumes `dist` is nonzero. If a light can coincide with a surface point, guard the normalization and attenuation math against division by zero.

<a id="snippet-9"></a>

## 9. Schlick Fresnel and blending a reflection

**Use for:** Increasing reflectance at grazing angles and blending a base color with an environment reflection. This pattern appears in [`light_6/frag.glsl`](./materials/light_6/frag.glsl).

```glsl
float cosTheta = max(dot(normal, viewDir), 0.0);
float fresnel = F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);

vec3 reflectDir = reflect(-viewDir, normal);
vec3 reflection = skyColor(reflectDir);
vec3 result = mix(base, reflection, fresnel);
```

### How to use it

1. Normalize `normal` and `viewDir`.
2. Set `F0` to the reflectance at a head-on angle (often about `0.04` for a simple dielectric example).
3. Compute the reflection direction from the incoming camera ray and surface normal.
4. Sample or evaluate an environment color for that direction.
5. Use the Fresnel value to blend from the base toward the reflection.

This project uses a procedural `skyColor` function rather than a full environment map. This simple scalar form is suitable for the reflection example; PBR materials commonly use vector-valued `F0`.

<a id="snippet-10"></a>

## 10. PBR Cook-Torrance specular term

**Use for:** A microfacet specular calculation in a physically based material shader. The project's implementation is in [`light_7/frag.glsl`](./materials/light_7/frag.glsl).

```glsl
float D = distributionGGX(NdotH, roughness);
float G = geometrySmith(NdotV, NdotL, roughness);
vec3 F = fresnelSchlick(HdotV, F0);

vec3 specular =
    (D * G * F) / max(4.0 * NdotV * NdotL, 0.001);
```

### How to use it

1. Compute normalized normal `N`, view direction `V`, and light direction `L`.
2. Compute the half-vector `H = normalize(V + L)`.
3. Evaluate the distribution `D`, geometry `G`, and Fresnel `F` functions for the material's roughness and reflectance.
4. Divide by the geometric normalization term, clamping its denominator away from zero.
5. Combine the specular response with diffuse and light radiance according to the material model.

This is not a complete lighting model by itself: it needs valid inputs, light radiance, a diffuse term, and an energy-conserving treatment of metallic and dielectric materials.

<a id="snippet-11"></a>

## 11. Reusable Cook-Torrance helper functions

**Use for:** Reusing the GGX normal distribution, Schlick-GGX/Smith geometry, and Schlick Fresnel terms in a microfacet PBR shader. These functions follow the implementation in [`light_7/frag.glsl`](./materials/light_7/frag.glsl).

```glsl
const float PI = 3.14159265359;

float distributionGGX(float NdotH, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float nDotH2 = NdotH * NdotH;
    float denom = nDotH2 * (a2 - 1.0) + 1.0;
    return a2 / (PI * denom * denom);
}

float geometrySchlickGGX(float NdotX, float roughness) {
    float k = pow(roughness + 1.0, 2.0) / 8.0;
    return NdotX / (NdotX * (1.0 - k) + k);
}

float geometrySmith(float NdotV, float NdotL, float roughness) {
    return geometrySchlickGGX(NdotV, roughness)
         * geometrySchlickGGX(NdotL, roughness);
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    float grazing = pow(1.0 - clamp(cosTheta, 0.0, 1.0), 5.0);
    return F0 + (1.0 - F0) * grazing;
}
```

### How to use it

1. Clamp `roughness` to a usable range such as `[0.04, 1.0]` in your material setup.
2. Compute normalized `N`, `V`, and `L`; then compute `H = normalize(V + L)`.
3. Pass clamped dot products such as `max(dot(N, H), 0.0)` to the distribution function.
4. Combine the returned `D`, `G`, and `F` values with the Cook-Torrance specular term in section 10.

The geometry function shown uses the direct-light Schlick-GGX convention in the project. Other rendering workflows may use a different roughness remapping or geometry approximation, so keep the convention consistent with the chosen BRDF.

<a id="snippet-12"></a>

## 12. Tone mapping and gamma correction

**Use for:** Converting nonnegative HDR lighting results into a displayable range, then applying the project's simple gamma adjustment. This is based on [`light_7/frag.glsl`](./materials/light_7/frag.glsl).

```glsl
vec3 toneMapAndGammaCorrect(vec3 hdrColor) {
    vec3 mapped = hdrColor / (hdrColor + vec3(1.0));
    return pow(max(mapped, vec3(0.0)), vec3(1.0 / 2.2));
}

void main() {
    vec3 hdrColor = directLighting + ambientLighting;
    vec3 displayColor = toneMapAndGammaCorrect(hdrColor);
    fragColor = vec4(displayColor, 1.0);
}
```

### How to use it

1. Accumulate lighting in linear color space and allow values above `1.0`.
2. Apply the tone-map curve component-wise to compress bright values into the display range.
3. Apply gamma correction after tone mapping.
4. Write the resulting display color.

This is the simple tone-map and gamma sequence used by the project, not a universal color-management pipeline. If the renderer or output target already performs an sRGB conversion, avoid applying a second gamma transform.

<a id="snippet-13"></a>

## 13. POM height sampling and filtered color lookup

**Use for:** Sampling a height field during Parallax Occlusion Mapping and then sampling the shifted material texture. The implementation is in [`parallax_2/frag.glsl`](./materials/parallax_2/frag.glsl).

```glsl
float sampleHeight(vec2 uv) {
    return smoothstep(0.15, 0.55, textureLod(u_heightMap, uv, 0.0).r);
}

vec3 color = textureGrad(
    u_texture,
    parallaxUV,
    dFdx(v_uv),
    dFdy(v_uv)
).rgb;
```

### How to use it

1. Sample a height texture at explicit LOD inside the iterative height search.
2. Use the height values to march a view ray through layers and find a displaced UV coordinate.
3. Sample the material texture at the displaced coordinate.
4. Supply derivatives from the original UVs so the texture filter has stable gradients even though the displaced UVs can change abruptly.

The thresholds in `smoothstep` are content-specific and shape how the height range is interpreted. POM adds per-fragment work; layer count and height scale trade visual detail against performance and stability.

<a id="snippet-14"></a>

## 14. Procedural indexed quad construction

**Use for:** Building a quad and appending it into a larger indexed mesh. The project's cube builder uses this pattern in [`scene.ts`](./procedural_mesh_basics/procedural_mesh_7/scene.ts).

```ts
const indices = [0, 1, 2, 0, 2, 3];
const vertexOffset = target.vertices.length / 3;

target.vertices.push(...quad.vertices);
target.normals.push(...quad.normals);
target.uvs.push(...quad.uvs);
quad.indices.forEach((index) => {
    target.indices.push(index + vertexOffset);
});
```

### How to use it

1. Keep each vertex attribute array aligned: three position values and three normal values, or two UV values, per vertex.
2. Define triangles with indices relative to the quad's own four vertices.
3. Before appending, compute the number of vertices already in the target.
4. Add that offset to each local index so it refers to the appended quad.

If vertices are duplicated for flat face normals or per-face UVs, account for that duplication when calculating offsets. If adding another vertex attribute such as color, append corresponding values as well.

<a id="snippet-15"></a>

## 15. Mouse-centered ripple and falloff

**Use for:** Distorting a texture and varying its blend around an interactive
UV-space center. This follows [`interact_5/frag.glsl`](./interactive/interact_5/frag.glsl):

```glsl
float dist = distance(v_uv, u_mousePosition);
float wave1 = sin(dist * 8.0 - u_time * 2.0) * 0.1;
float wave2 = sin(dist * 8.0 * 0.5 - u_time * 2.0 * 0.7) * 0.1 * 0.7;
float wave3 = sin(dist * 8.0 * 0.3 - u_time * 2.0 * 0.5) * 0.1 * 0.5;
float wave = wave1 + wave2 + wave3;
float falloff = 1.0 - smoothstep(0.0, 0.4, dist);
vec2 offset = vec2(wave * 0.02);
vec4 sampled = texture(u_texture, v_uv + offset);
fragColor = mix(vec4(0.1, 0.1, 0.1, 1.0), sampled,
                abs(wave) * falloff + 0.3);
```

Supply a mouse position in the same UV space and orientation as `v_uv`, and
update `u_time`. The offset moves U and V by the same amount, not radially.
The falloff affects the color blend, not the offset; outside the radius the
texture still contributes 30%. UV-space circles can look elliptical on a
non-square surface, and out-of-range texture lookup behavior depends on
sampler wrapping. See the [ripple walkthrough](./interactive/interact_5/CODE_EXPLANATION.md).

<a id="snippet-16"></a>

## 16. Animated screen-space scanlines

**Use for:** Darkening a texture with moving horizontal bands, as in
[`uv_4/frag.glsl`](./uv/uv_4/frag.glsl):

```glsl
vec2 uv = gl_FragCoord.xy / u_resolution;
float movingY = uv.y + u_time * 0.2;
float scanline = sin(movingY * 100.0) * 0.5 + 0.5;
scanline = mix(1.0, scanline, 0.2);
vec3 color = texture(u_texture, uv).rgb;
fragColor = vec4(color * scanline, 1.0);
```

Use nonzero framebuffer dimensions and update them on resize. This assumes a
zero-origin full-frame viewport; an offset viewport needs its origin subtracted
for viewport-local UVs. `100.0` is radians per normalized vertical unit,
approximately 15.9 complete cycles across a unit height, not 100 lines. The
brightness multiplier ranges from `0.8` to `1.0`. In the standard lower-left
window coordinate convention the bands move toward decreasing Y. Texture alpha
is discarded. See the [scanline walkthrough](./uv/uv_4/CODE_EXPLANATION.md).

<a id="snippet-17"></a>

## 17. Deterministic particle targets and animation

**Use for:** Giving each input position a pseudo-random target and interpolating
toward it, following [`particle_2/vert.glsl`](./particles/particle_2/vert.glsl):

```glsl
float random(vec3 seed) {
    return fract(sin(dot(seed, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

// Inside the vertex shader's main:
vec3 offset = vec3(
    random(position + vec3(1.0, 0.0, 0.0)),
    random(position + vec3(0.0, 1.0, 0.0)),
    random(position + vec3(0.0, 0.0, 1.0))
) * 4.0 - 2.0;
float progress = u_time / u_maxTime;
vec3 newPos = mix(position, position + offset, progress);
gl_PointSize = 2.0;
gl_Position = worldViewProjection * vec4(newPos, 1.0);
```

Supply a positive nonzero `u_maxTime`, and update `u_time` in the same units.
The project does not clamp progress: values outside `[0, 1]` extrapolate past
the start or target. Each offset component is nominally in `[-2, 2)`;
identical positions receive identical offsets. This sine hash is not
cryptographically secure or guaranteed to match exactly across GPUs.
The host must draw point primitives for `gl_PointSize` to produce point
particles. The example's [fragment shader](./particles/particle_2/frag.glsl)
derives binary RGB channels from the animated world position, so colors can
change during movement. Use a separate stable seed if fixed colors are needed.

<a id="snippet-18"></a>

## 18. Red-channel threshold transition

**Use for:** Hiding pixels according to the sampled red channel, as in
[`image_transition_1/frag.glsl`](./image_transitions/image_transition_1/frag.glsl):

```glsl
vec4 color = texture(u_texture, v_uv);
float progress = u_time / u_maxTime;
float mask = step(progress, color.r);
color.a *= mask;
fragColor = color;
```

Use a positive nonzero `u_maxTime`. A sampled red value below `progress` gets
alpha zero; one equal to or above it retains its original alpha. RGB is not
changed, and transparent pixels do not disappear visually unless the host uses
appropriate blending or another transparency strategy. Progress is not
clamped. The mask comes from the same texture's red channel, not a separate
noise map; it is a color-driven threshold rather than a crossfade.

<a id="snippet-19"></a>

## 19. Lathe surface and profile normal

**Use for:** Revolving a radius profile around the Y axis, following
[`lathe_1/scene.ts`](./procedural_mesh_basics/lathe_1/scene.ts):

```ts
const t = row / rows;
const u = segment / segments;
const angle = startAngle + u * Math.PI * 2;
const radius = radiusAt(t);
const y = (t - 0.5) * height;
const eps = 0.001;
const slope = (radiusAt(t + eps) - radiusAt(t - eps)) / (2 * eps * height);
const length = Math.sqrt(1 + slope * slope);

mesh.vertices.push(radius * Math.cos(angle), y, radius * Math.sin(angle));
mesh.uvs.push(u, t);
mesh.normals.push(Math.cos(angle) / length, -slope / length, Math.sin(angle) / length);
```

Use positive `rows`, `segments`, and `height`, and a profile that can be
evaluated slightly beyond both endpoints for the centered difference. Generate
rows and segments inclusively to duplicate the seam at `u = 0` and `u = 1`;
then connect adjacent rows with indexed triangles. The derivative estimates
`dr/dy`, tilting the normal along the profile rather than pointing it purely
outward. The example builds the side surface, not top or bottom caps. See the
[lathe explanation](./procedural_mesh_basics/lathe_1/CODE_EXPLANATION.md).

<a id="snippet-20"></a>

## 20. Rotation matrices and a local pivot

**Use for:** Rotating geometry about a local-space axis with an adjustable
angle and pivot. These `mat4` helpers follow the explicit matrix style of
the [X](./transforms/transform_4/vert.glsl) and
[Y](./transforms/transform_2/vert.glsl) rotation lessons. Define the helpers
you need outside `main`.

### X, Y, and Z axes

```glsl
mat4 getRotationMatrixX(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat4(
        1.0, 0.0, 0.0, 0.0,
        0.0,   c,  -s, 0.0,
        0.0,   s,   c, 0.0,
        0.0, 0.0, 0.0, 1.0
    );
}

mat4 getRotationMatrixY(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat4(
          c, 0.0,   s, 0.0,
        0.0, 1.0, 0.0, 0.0,
         -s, 0.0,   c, 0.0,
        0.0, 0.0, 0.0, 1.0
    );
}

mat4 getRotationMatrixZ(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat4(
          c,  -s, 0.0, 0.0,
          s,   c, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0
    );
}
```

GLSL fills these constructors by **columns**. The X and Y matrices match the
lesson shaders; Z follows the same sign convention but is not a separate
lesson shader. In a conventional right-handed XYZ basis, a positive `angle`
here corresponds to an active right-handed rotation by **negative** `angle`.
Negate it for the conventional positive direction. The camera determines the
apparent screen direction.

### Optional: arbitrary axis

For an axis other than X, Y, or Z, this matrix uses the same sign convention.
The host must supply a **nonzero** local-space `rotationAxis`:

```glsl
mat4 getRotationMatrixAxis(vec3 unitAxis, float angle) {
    float x = unitAxis.x;
    float y = unitAxis.y;
    float z = unitAxis.z;
    float c = cos(angle);
    float s = -sin(angle);
    float t = 1.0 - c;
    return mat4(
        t*x*x+c,   t*x*y+s*z, t*x*z-s*y, 0.0,
        t*x*y-s*z, t*y*y+c,   t*y*z+s*x, 0.0,
        t*x*z+s*y, t*y*z-s*x, t*z*z+c,   0.0,
        0.0,       0.0,       0.0,       1.0
    );
}
```

Call it with `getRotationMatrixAxis(normalize(rotationAxis), angle)`. The
input must be unit length; never normalize a zero axis.

### Apply a rotation and keep lighting consistent

Supply `angle` in radians and `pivot` in local coordinates. For example, in
`main`, select the Y helper; replace it with another helper as needed:

```glsl
mat4 rotation = getRotationMatrixY(angle);
vec4 localPos = rotation * vec4(position - pivot, 1.0);
localPos.xyz += pivot;
vec3 localNormal = normalize(mat3(rotation) * normal);
vPosition = (world * localPos).xyz;
vNormal = normalize(worldNormalMatrix * localNormal);
gl_Position = worldViewProjection * localPos;
```

The pivot affects positions, not normals. Set it to `vec3(0.0)` to rotate
around the local origin. Supply consistent `world` and
`worldViewProjection` matrices. `worldNormalMatrix` is the inverse
transpose of the world's linear 3-by-3 part; supply it from the host for an
invertible world transform. For animation, calculate the angle from an
initial angle, angular speed, and elapsed time.

See the [transformation guide](./transforms/README.md) for worked examples
and coordinate conventions.

<a id="snippet-21"></a>

## 21. Taper over a local coordinate range

**Use for:** Changing a cross-section's Y size along local Z with configurable
end scales and a configurable Y center:

```glsl
float t = clamp((position.z - zStart) / (zEnd - zStart), 0.0, 1.0);
float factor = mix(scaleAtStart, scaleAtEnd, t);
vec3 taperedPosition = position;
taperedPosition.y = centerY + (position.y - centerY) * factor;
```

Supply `zStart`, `zEnd`, `scaleAtStart`, `scaleAtEnd`, and `centerY` in local
coordinates or units as appropriate. Require `zEnd > zStart`; otherwise the
division is invalid or the intended range is reversed. At and beyond either
endpoint, clamping holds the corresponding end scale; remove `clamp` only if
extrapolation is intended. X and Z remain unchanged.

For example, scales of `0.5` and `1.5` at the two ends give factor `1.0` at
the midpoint. Choose positive end scales to avoid collapse or reflection over
the clamped range. A zero factor makes the deformation singular; a negative
factor flips the cross-section and can affect culling.

Use the tapered position for both world-space lighting and clip-space output.
For correct continuous-surface normals, account for the factor's spatial
derivative with the deformation Jacobian and then apply the world normal
transform. The clamped factor has a derivative discontinuity at the
endpoints when the end scales differ. The
[taper walkthrough](./transforms/transform_8/CODE_EXPLANATION.md) explains a
specific unclamped example and its normal calculation.

<a id="snippet-22"></a>

## 22. Twist along a local axis

**Use for:** Twisting XZ cross-sections around local Y with configurable base
angle, reference height, and twist rate:

```glsl
float angle = baseAngle + twistPerUnit * (position.y - referenceY);
float c = cos(angle);
float s = sin(angle);
vec3 twistedPosition = vec3(
    position.x * c - position.z * s,
    position.y,
    position.x * s + position.z * c
);
```

Supply `baseAngle` in radians, `twistPerUnit` in radians per local Y unit,
and `referenceY` in local Y coordinates. At `referenceY` the angle is
`baseAngle`; with `twistPerUnit = 0` the result is a rigid Y rotation. The
host can animate these parameters, but this pattern does not require time.
The sign matches the project's
[twist example](./transforms/transform_9/vert.glsl), which is a negative-angle
rotation under the conventional active right-handed rule.

Each vertex retains its distance from the local Y axis. Triangles remain
piecewise linear between transformed vertices, so subdivision affects the
visible approximation. Use the deformed position for lighting and rendering.
For a continuous surface, transform normals using the inverse transpose of the
local deformation Jacobian followed by the world normal transform. Simply
rotating each normal by its local angle, as in
[lesson 10](./transforms/transform_10/CODE_EXPLANATION.md), omits the angle
gradient and is generally approximate.

<a id="snippet-23"></a>

## 23. Scale geometry around a local pivot

**Use for:** Resizing geometry uniformly or independently along each local
axis. Supply the scale and pivot in the vertex shader; these are independent
patterns, not code to paste together unchanged.

### Uniform scale

```glsl
mat4 scale = mat4(
    uniformScale, 0.0,          0.0,          0.0,
    0.0,          uniformScale, 0.0,          0.0,
    0.0,          0.0,          uniformScale, 0.0,
    0.0,          0.0,          0.0,          1.0
);
vec4 localPos = scale * vec4(position - pivot, 1.0);
localPos.xyz += pivot;
```

`pivot` is a local-space point and `uniformScale` is a dimensionless factor
applied equally to X, Y, and Z. For example, with pivot `(1, 0, 0)`, position
`(2, 1, -1)`, and scale `2`, the result is `(3, 2, -2)`. Set `pivot` to
`vec3(0.0)` to scale around the local origin. GLSL fills a `mat4` constructor
by columns; the diagonal sets the three scale factors and preserves the
homogeneous `w` component.

### Non-uniform scale and lighting

```glsl
mat4 scale = mat4(
    scaleFactors.x, 0.0,            0.0,            0.0,
    0.0,            scaleFactors.y, 0.0,            0.0,
    0.0,            0.0,            scaleFactors.z, 0.0,
    0.0,            0.0,            0.0,            1.0
);
vec4 localPos = scale * vec4(position - pivot, 1.0);
localPos.xyz += pivot;
mat3 localNormalMatrix = transpose(inverse(mat3(scale)));
vec3 scaledNormal = localNormalMatrix * normal;
vPosition = (world * localPos).xyz;
vNormal = normalize(worldNormalMatrix * scaledNormal);
gl_Position = worldViewProjection * localPos;
```

`scaleFactors` is a `vec3` of dimensionless X, Y, and Z factors; all three
components must be nonzero for the inverse. The pivot affects
positions but not normals. For example, position `(2, 1, -1)`, pivot
`(1, 0, 0)`, and factors `(2, 0.5, 1.5)` produce `(3, 0.5, -1.5)`.

`localNormalMatrix` is the inverse transpose of the local diagonal scale.
For this diagonal matrix, `normal / scaleFactors` gives the same direction
without computing a matrix inverse. Supply `worldNormalMatrix` as the inverse
transpose of the world's linear 3-by-3 part, and use an invertible world
transform. `worldViewProjection` must include the same `world` matrix used
for `vPosition`. With non-uniform scaling, multiplying the normal directly
by `scaleFactors` generally does not preserve perpendicularity.

A zero factor collapses an axis and has no ordinary inverse normal transform.
Negative factors reflect axes; an odd number of negative factors reverses
orientation and may require adjusting face culling. Choose the desired
reflection and culling behavior explicitly.

### Animated uniform scale

```glsl
float uniformScale = baseScale
    + amplitude * sin(angularFrequency * elapsedTime);
mat4 scale = mat4(
    uniformScale, 0.0,          0.0,          0.0,
    0.0,          uniformScale, 0.0,          0.0,
    0.0,          0.0,          uniformScale, 0.0,
    0.0,          0.0,          0.0,          1.0
);
vec4 localPos = scale * vec4(position - pivot, 1.0);
localPos.xyz += pivot;
```

The host supplies `baseScale`, `amplitude`, `angularFrequency` in radians per
time unit, and `elapsedTime` in matching units. To keep the scale strictly
positive throughout the cycle, choose `baseScale > abs(amplitude)`. Use the
same scaled position for lighting and rendering. The
[animated scale lesson](./transforms/transform_6/CODE_EXPLANATION.md) shows a
specific oscillation; its current shader calculates lighting position from the
original vertex rather than the scaled one.

<a id="snippet-checklist"></a>

## General integration checklist

- Match vertex-shader outputs with fragment-shader inputs by name and type.
- Bind every attribute, uniform, texture, and framebuffer attachment expected by the shader.
- Keep positions, normals, light directions, and camera directions in compatible coordinate spaces.
- Keep texture UV orientation and depth conventions consistent across rendering passes.
- Normalize direction vectors before dot products and guard any division that could use a zero-length vector.
- Treat color encoding, alpha clear values, and G-buffer packing as a contract between the pass that writes data and the pass that reads it.
