# Common Code Snippets and Usage Guide

This guide collects reusable patterns found in the project's GLSL shaders and procedural-mesh code. Each example includes its purpose, how to use it, and important assumptions. Snippets are representative; adapt names and data sources to the shader and renderer that use them.

For definitions and formulas for the terms used below, see the project [glossary](./GLOSSARY.md).

## 1. Standard vertex transformation

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

## 2. Instanced vertex transformation

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

## 3. Sampling a 2D texture

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

## 4. Writing multiple render targets (MRT)

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

## 5. Encoding and decoding normals

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

## 6. Reconstructing world position from depth

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

## 7. Lambert diffuse point-light contribution

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

## 8. Schlick Fresnel and blending a reflection

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

## 9. PBR Cook-Torrance specular term

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

## 10. Reusable Cook-Torrance helper functions

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
4. Combine the returned `D`, `G`, and `F` values with the Cook-Torrance specular term in section 9.

The geometry function shown uses the direct-light Schlick-GGX convention in the project. Other rendering workflows may use a different roughness remapping or geometry approximation, so keep the convention consistent with the chosen BRDF.

## 11. Tone mapping and gamma correction

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

## 12. POM height sampling and filtered color lookup

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

## 13. Procedural indexed quad construction

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

## 14. Common GLSL built-in functions

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

Use powers for Fresnel, highlight shaping, and the project's approximate gamma transform. Perform display conversion only once; see section 11 and [`light_7/frag.glsl`](./materials/light_7/frag.glsl).

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

## General integration checklist

- Match vertex-shader outputs with fragment-shader inputs by name and type.
- Bind every attribute, uniform, texture, and framebuffer attachment expected by the shader.
- Keep positions, normals, light directions, and camera directions in compatible coordinate spaces.
- Keep texture UV orientation and depth conventions consistent across rendering passes.
- Normalize direction vectors before dot products and guard any division that could use a zero-length vector.
- Treat color encoding, alpha clear values, and G-buffer packing as a contract between the pass that writes data and the pass that reads it.
