# Shader Academy Project Glossary

This glossary defines graphics, shader, material, and geometry terms used in the project's GLSL shaders, TypeScript mesh code, and shader explanations. Entries include links to representative examples.

For reusable shader and mesh implementations of these concepts, see the [common code snippets guide](./CODE_SNIPPETS.md).
In the notebook, links to examples outside its public-content allowlist remain
repository-relative; open those files in the repository instead.

### Notation used in formulas
Vectors such as the normal `N`, light direction `L`, and view direction `V` are assumed to be normalized unless noted. `dot(a, b)` is the dot product, `clamp(x, 0, 1)` limits a scalar to `[0, 1]`, and `ρ` denotes a reflectance or color value. Shader code may omit factors such as `1/π` for a simplified visual model.

## A

### Albedo
The base color of a surface before lighting is applied. In a metallic/roughness material, it describes the diffuse color of a non-metal and the characteristic reflected color of a metal. The deferred-lighting shader reads albedo from a G-buffer texture ([`gbuffer_5/frag.glsl`](./g_buffer/gbuffer_5/frag.glsl)); the PBR shader also defines it as a material property ([`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

**Formula:** In code, albedo is the base-color vector `ρ` (for example, `albedo.rgb`). A simple Lambertian outgoing contribution is proportional to `ρ · max(N·L, 0)`.

### Aliasing
Visible jaggedness, flickering, or shimmering caused when a continuous image detail is sampled too coarsely. The parallax shader uses explicit texture gradients when sampling its shifted UVs to help maintain suitable texture filtering ([`parallax_2/frag.glsl`](./materials/parallax_2/frag.glsl)).

### Alpha
The fourth component of an RGBA color, often used for opacity or as a marker. The G-buffer lighting pass treats zero albedo alpha as an empty pixel ([`gbuffer_5/frag.glsl`](./g_buffer/gbuffer_5/frag.glsl)).

### Attenuation
Reduction in a light's contribution with distance. In the G-buffer lighting shader, the point-light contribution is scaled by `1.0 / (1.0 + 0.03 * dist * dist)` ([`gbuffer_5/frag.glsl`](./g_buffer/gbuffer_5/frag.glsl)).

**Project formula:** `A(d) = 1 / (1 + 0.03 d²)`, where `d` is the distance from the shaded point to the light.

## B

### Bitangent
One axis of a tangent-space surface frame, together with the tangent and normal. It helps express view and lighting directions relative to a surface. The parallax shader defines a plane's tangent, bitangent, and normal explicitly ([`parallax_2/frag.glsl`](./materials/parallax_2/frag.glsl)).

### BRDF (Bidirectional Reflectance Distribution Function)
A function describing how much incoming light is reflected toward a viewing direction for a given surface. The PBR shader combines diffuse and specular terms using the Cook-Torrance microfacet BRDF ([`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

**Rendering equation:** `Lₒ(x, V) = ∫Ω fᵣ(x, L, V) Lᵢ(x, L) max(N·L, 0) dωᵢ`. Here `fᵣ` is the BRDF, `Lᵢ` incoming radiance, and the integral sums light over the hemisphere above the surface.

## C

### Clip space
The coordinate space produced by the vertex shader before clipping and perspective division. A vertex shader writes a homogeneous clip-space position to `gl_Position`; the procedural-mesh shader gets there by applying instance, view, and projection transforms ([`procedural_mesh_7/vert.glsl`](./procedural_mesh_basics/procedural_mesh_7/vert.glsl)).

### Cook-Torrance model
A microfacet model for specular reflection. In this project's PBR shader, its specular term combines a normal-distribution function, a geometry function, and a Fresnel function ([`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

**Specular formula:** `f_spec = (D · G · F) / max(4(N·V)(N·L), ε)`, where `ε` is a small positive guard against division by zero.

### Coordinate space
A frame of reference used to describe positions or directions. The project uses local/object, world, view, clip, normalized-device, screen, and tangent spaces. Transformations between these spaces are performed with matrices or basis vectors.

**Typical position transform:** `p_clip = P · V · M · p_local`, where `M` is the model/world matrix, `V` the view matrix, and `P` the projection matrix. Matrix/vector convention and multiplication order must match the renderer.

## D

### Deferred shading / deferred lighting
A rendering approach that separates geometry capture from lighting. A geometry pass writes surface properties to G-buffer textures; a later pass reads those textures and computes illumination. The G-buffer 5 shader reconstructs each pixel's world position and lights it afterward ([`gbuffer_5/frag.glsl`](./g_buffer/gbuffer_5/frag.glsl)).

**Pass relationship:** `G-buffer = geometry(position, normal, albedo, depth)`; `finalColor = lighting(G-buffer, lights, camera)`.

### Deformation
A position-dependent change to a shape, such as a taper or twist. The
[transform lessons](./transforms/README.md) apply these changes to vertices;
triangles between them approximate the continuous deformation. Normals may
need a deformation-aware transform for correct lighting.

### Depth buffer
A per-pixel buffer used to determine which surfaces are in front of others. The shaders also copy depth into a color texture for later sampling. Under the conventional perspective projection used here, depth is non-linear with distance ([`gbuffer_2/frag.glsl`](./g_buffer/gbuffer_2/frag.glsl), [`gbuffer_4/frag.glsl`](./g_buffer/gbuffer_4/frag.glsl)).

**Depth/NDC mapping used by the shaders:** `z_ndc = 2d - 1` and `d = (z_ndc + 1)/2`, where `d ∈ [0,1]`.

### Diffuse reflection
Light scattered broadly from a surface rather than reflected as a sharp highlight. The project uses Lambert-style dot-product lighting in the reflection and deferred-lighting examples and an energy-conserving diffuse term in its PBR shader ([`light_6/frag.glsl`](./materials/light_6/frag.glsl), [`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

**Lambertian formula:** `Lₒ,diffuse = (ρ/π) Lᵢ max(N·L, 0)`. The simpler project lighting snippets omit `1/π` and use `ρ Lᵢ max(N·L, 0)`.

### Dot product
An operation on two vectors that, for normalized vectors, gives the cosine of the angle between them. Shaders use it to measure how much a surface faces a light or view direction. Negative diffuse results are clamped to zero with `max` ([`gbuffer_5/frag.glsl`](./g_buffer/gbuffer_5/frag.glsl)).

**Formula:** `a·b = aₓbₓ + aᵧbᵧ + a_zb_z`; if both vectors are unit length, `a·b = cos θ`.

## E

### Energy conservation
A lighting principle that prevents a surface from reflecting more energy than it receives. The PBR shader reduces the diffuse contribution as the Fresnel reflection increases and suppresses diffuse reflection for metals ([`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

**Project split:** `k_S = F`, `k_D = (1 - F)(1 - metallic)`. Thus metals (`metallic = 1`) receive no diffuse weight, and the remaining diffuse weight decreases as reflectance `F` increases.

### Environment reflection
Reflected light or scenery arriving from the surrounding environment. The reflection and PBR examples approximate the environment with a procedural sky-color function rather than sampling a full environment map ([`light_6/frag.glsl`](./materials/light_6/frag.glsl), [`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

**Lookup:** `L_environment = skyColor(R)`, where `R = reflect(-V, N)`.

## F

### Falloff
The reduction of an effect as distance or another quantity increases. The
[ripple shader](./interactive/interact_5/frag.glsl) uses
`1 - smoothstep(0, radius, distance)` to fade its wave's contribution to the
color blend; its texture-coordinate offset is not faded by that value.

### F0
The reflectance at normal incidence (viewing a surface head-on). The simple reflection shader uses approximately `0.04` for a typical non-metal; the PBR shader uses that value for dielectrics and the albedo for metals ([`light_6/frag.glsl`](./materials/light_6/frag.glsl), [`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

**Dielectric estimate:** `F₀ = ((η₁ - η₂)/(η₁ + η₂))²`, where `η₁` and `η₂` are the refractive indices on either side of the interface. The shader uses the common approximate value `0.04` for non-metals.

### Face winding
The order in which a triangle's vertices are listed. It determines the triangle's front-facing orientation when face culling is enabled. `createQuad` can append reversed-winding indices to make the quad's triangles available from either side ([`scene.ts`](./procedural_mesh_basics/procedural_mesh_7/scene.ts)).

**Orientation test:** The sign of `((p₁-p₀) × (p₂-p₀)) · viewDirection` distinguishes the two triangle orientations, with the exact front-face sign depending on the graphics API and view convention.

**Visual example:** Looking at the triangle from the front, with `+Z` toward the viewer:

```text
Counterclockwise (CCW)             Clockwise (CW)

          2                                  2
         / \                                / \
        /   \                              /   \
       /     \                            /     \
      0 ----> 1                          0 <---- 1

   order: 0 → 1 → 2                  order: 0 → 2 → 1
```

The arrows show the direction along the bottom edge; continue around the other two edges to complete the vertex order. Reversing the order flips the triangle's facing. With the default OpenGL/WebGL front-face convention, CCW triangles are front-facing, but the renderer can change this convention.

### Fragment
A candidate pixel generated when a primitive is rasterized. A fragment shader calculates its output color and may write additional render-target values, such as depth or normals.

### Fragment shader
A programmable GPU stage that runs for rasterized fragments. It samples textures and computes output colors; G-buffer examples can also write multiple outputs ([`gbuffer_4/frag.glsl`](./g_buffer/gbuffer_4/frag.glsl)).

**Output model:** A fragment shader computes an output such as `fragColor = vec4(color, alpha)`; with MRT, it can also write other outputs at separately assigned locations.

### Fresnel effect
The increase in reflectance at grazing angles, where a surface is viewed nearly edge-on. The project implements Schlick's approximation in its reflection and PBR shaders ([`light_6/frag.glsl`](./materials/light_6/frag.glsl), [`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

**Schlick formula:** `F(θ) = F₀ + (1 - F₀)(1 - cos θ)⁵`, with `cos θ = max(N·V, 0)`. In PBR, `F₀` and `F` may be RGB vectors.

## G

### Gamma correction
A nonlinear adjustment that converts linear-light shader results to values appropriate for display. The PBR shader applies a power of `1.0 / 2.2` after tone mapping ([`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

**Project formula:** `C_display = C_tone^(1/2.2)`, applied component-wise to nonnegative color values.

### G-buffer (Geometry Buffer)
A set of render targets that stores per-pixel surface data, such as albedo, depth, and normals, for a later rendering pass. This project's G-buffer examples progressively write and use those values ([`gbuffer_2/frag.glsl`](./g_buffer/gbuffer_2/frag.glsl), [`gbuffer_3/frag.glsl`](./g_buffer/gbuffer_3/frag.glsl), [`gbuffer_5/frag.glsl`](./g_buffer/gbuffer_5/frag.glsl)).

### GGX
A microfacet normal-distribution function used to shape specular highlights according to roughness. The PBR shader implements the GGX distribution in `distributionGGX` ([`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

**Project formula:** Let `a = r²`, `a² = a·a`, and `NdotH = max(N·H, 0)`. Then `D_GGX = a² / (π [NdotH²(a² - 1) + 1]²)`.

### GLSL ES
The OpenGL ES Shading Language used by WebGL. The project's shader files declare version `300 es`, corresponding to GLSL ES 3.00 ([`procedural_mesh_7/vert.glsl`](./procedural_mesh_basics/procedural_mesh_7/vert.glsl)).

### Geometry function
In a microfacet BRDF, a factor accounting for microfacets that block incoming light or hide reflected light from the viewer. The PBR shader uses Schlick-GGX and Smith-style terms for this effect ([`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

**Project formula:** For one direction, `G₁(x,r) = x / (x(1-k)+k)`, with `k = (r+1)²/8`. For Smith's two-direction form, `G = G₁(N·V,r) G₁(N·L,r)`.

### Geometry shader (geometry pass)
A rendering pass that draws scene surfaces and records their attributes into render targets. In this project, the term refers to the pass that fills G-buffer textures; it is distinct from the optional programmable GPU stage also called a geometry shader.

### `gl_FragCoord`
A fragment-shader built-in containing window-space fragment coordinates.
The [scanline shader](./uv/uv_4/frag.glsl) divides its `xy` by framebuffer
resolution to obtain screen UVs; G-buffer examples use `z` as depth.
An offset viewport needs an origin adjustment for viewport-local coordinates.

## H

### Height map
A texture whose values represent surface height. Parallax mapping samples a height map to shift texture coordinates and create an apparent depth effect without changing the mesh silhouette ([`parallax_2/frag.glsl`](./materials/parallax_2/frag.glsl)).

**Project sampling formula:** `h = smoothstep(0.15, 0.55, textureLod(heightMap, uv, 0).r)`. GLSL's `smoothstep(e₀,e₁,x)` is `t²(3-2t)`, where `t = clamp((x-e₀)/(e₁-e₀), 0, 1)`.

### HDR (High Dynamic Range)
Color values that can represent light intensities beyond the display range of `[0, 1]`. PBR lighting can produce such values, so the shader tone maps them before display ([`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

### Homogeneous coordinates
Coordinates with an extra `w` component that allow translation and perspective transformations to be represented with matrix multiplication. Positions are commonly represented as `vec4(position, 1.0)` and divided by `w` after projection or unprojection.

**Formula:** `(x,y,z) → (x,y,z,1)` for a position; after transformation, `(x',y',z',w') → (x'/w',y'/w',z'/w')` when `w' ≠ 0`.

## I

### Indexed geometry
Mesh data in which an index array refers to entries in vertex-attribute arrays. It allows triangles to reuse vertices. The procedural cube builder offsets each quad's local indices when appending it to the full mesh ([`scene.ts`](./procedural_mesh_basics/procedural_mesh_7/scene.ts)).

**Index offset:** `vertexOffset = target.vertices.length / 3`; each appended index is `globalIndex = localIndex + vertexOffset` because each position uses three numbers.

### Instancing
Drawing multiple copies of a mesh while supplying per-instance data, such as a transform matrix, rather than duplicating all of its vertex data. The procedural-mesh vertex shader receives four matrix columns and per-instance identifiers ([`procedural_mesh_7/vert.glsl`](./procedural_mesh_basics/procedural_mesh_7/vert.glsl)).

## J

### Jacobian
The matrix of partial derivatives of a position-dependent transformation. It
describes the local change to tangent directions. Where it is invertible, its
inverse transpose transforms normals for the continuous deformation; the
[taper lesson](./transforms/transform_8/CODE_EXPLANATION.md) gives an example.

## L

### Lambertian diffuse
A simple diffuse-lighting model where brightness is proportional to the nonnegative dot product of the surface normal and light direction. It is used in the simple reflection and deferred-lighting shaders ([`light_6/frag.glsl`](./materials/light_6/frag.glsl), [`gbuffer_5/frag.glsl`](./g_buffer/gbuffer_5/frag.glsl)).

### Lathe / surface of revolution
A surface made by revolving a profile around an axis. The
[lathe mesh](./procedural_mesh_basics/lathe_1/scene.ts) revolves a radius
profile around Y, duplicates the UV seam, and estimates a profile slope to
tilt its normals.

### LDR (Low Dynamic Range)
A limited display range, commonly `[0, 1]` per color channel. Tone mapping converts HDR lighting results into this range for display.

### Linear interpolation (`mix`)
A weighted blend between two values. In GLSL, `mix(a, b, t)` blends from `a` to `b` as `t` moves from 0 to 1. The shaders use it for colors and for refining a parallax ray's surface intersection ([`light_6/frag.glsl`](./materials/light_6/frag.glsl), [`parallax_2/frag.glsl`](./materials/parallax_2/frag.glsl)).

**Formula:** `mix(a,b,t) = a(1-t) + bt`, applied component-wise.

## M

### Material ID
A value identifying a material or material category, rather than a smoothly varying surface property. The procedural-mesh vertex shader forwards the red component of vertex color as a flat material ID; the current fragment shader does not use it ([`procedural_mesh_7/vert.glsl`](./procedural_mesh_basics/procedural_mesh_7/vert.glsl)).

### Metallic
A material parameter describing whether a surface behaves like a metal or a dielectric (non-metal). In the PBR shader, metals use albedo-colored reflectance and have no diffuse term; non-metals use a base F0 near `0.04` ([`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

### Microfacet
A microscopic surface facet used by microfacet BRDF models to approximate the many tiny orientations on a rough surface. The PBR shader uses a microfacet distribution, geometry, and Fresnel terms to compute specular reflection ([`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

### MRT (Multiple Render Targets)
Writing several fragment outputs to separate color attachments in a single draw. The G-buffer shaders use explicit output locations to store screen color, depth, and in one stage normals ([`gbuffer_3/frag.glsl`](./g_buffer/gbuffer_3/frag.glsl), [`gbuffer_4/frag.glsl`](./g_buffer/gbuffer_4/frag.glsl)).

## N

### NDC (Normalized Device Coordinates)
The normalized coordinate space after perspective division and before viewport mapping. With the conventional WebGL/OpenGL clip-depth convention used by these examples, x, y, and z are in `[-1, 1]`. G-buffer shaders convert screen UV and sampled depth back into NDC before reconstructing world position ([`gbuffer_4/frag.glsl`](./g_buffer/gbuffer_4/frag.glsl), [`gbuffer_5/frag.glsl`](./g_buffer/gbuffer_5/frag.glsl)).

**Screen-to-NDC mapping:** `x_ndc = 2u - 1`, `y_ndc = 2v - 1`, and `z_ndc = 2d - 1`, where `(u,v)` are screen UVs and `d` is the sampled depth. Reconstruction then applies `p_world_h = inverse(PV) · (x_ndc, y_ndc, z_ndc, 1)` and `p_world = p_world_h.xyz / p_world_h.w`.

### Normal
A vector perpendicular to a surface, used to determine how the surface faces lights and the viewer. The project transforms normals in vertex shaders, stores them in a G-buffer, and decodes them from `[0, 1]` when needed ([`gbuffer_3/frag.glsl`](./g_buffer/gbuffer_3/frag.glsl), [`gbuffer_5/frag.glsl`](./g_buffer/gbuffer_5/frag.glsl)).

**G-buffer encoding:** `n_encoded = 0.5n + 0.5`; decoding is `n = normalize(2n_encoded - 1)`, component-wise.

### Normal matrix
The inverse transpose of the linear part of an object's transform. It correctly transforms normals when the object has non-uniform scaling or shear. Some project vertex shaders use the simpler upper-left `mat3(world)` transform, which is suitable for rotation and uniform scale but not every transform.

**Formula:** `n_world = normalize((M₃×₃⁻¹)ᵀ n_local)`, where `M₃×₃` is the linear (upper-left 3×3) part of the world transform and is invertible. A position-dependent deformation additionally needs its local Jacobian's inverse transpose.

## P

### Parallax mapping
A family of techniques that shifts texture coordinates based on view direction and height data to simulate surface relief without adding geometric detail ([`parallax_2/frag.glsl`](./materials/parallax_2/frag.glsl)).

### Parallax Occlusion Mapping (POM)
A parallax technique that marches a view ray through height layers to estimate where it intersects the height field. The project samples multiple layers and interpolates between the last two samples for a smoother intersection ([`parallax_2/frag.glsl`](./materials/parallax_2/frag.glsl), [`POM_Explanation.md`](./materials/parallax_2/POM_Explanation.md)).

**Layer step:** For `N` layers, `Δh = 1/N` and `Δuv = uvPerHeight · Δh`. March `h_ray` down by `Δh` while stepping UV by `Δuv`; refine the crossing with `uv_hit = mix(uv_before, uv_after, t)`, where `t = gap_before/(gap_before + gap_after)`.

### Particle
An individual element in a particle effect, often drawn as a point or small
sprite. The project's [static](./particles/particle_1/vert.glsl) and
[animated](./particles/particle_2/vert.glsl) examples displace input vertices;
the host must choose point drawing and supply any particle management.

### Perspective divide
Dividing a homogeneous position's `xyz` components by its `w` component. It converts clip coordinates into normalized coordinates and is also used after inverse view-projection to recover a Cartesian world-space position ([`gbuffer_5/frag.glsl`](./g_buffer/gbuffer_5/frag.glsl)).

**Formula:** For homogeneous `p = (x, y, z, w)`, the Cartesian point is `(x/w, y/w, z/w)`, provided `w ≠ 0`.

### Pivot
The point around which a rotation or scale is applied. The transformation
lessons operate around the local origin. To rotate around a different pivot
with column vectors, apply `T(pivot) * R * T(-pivot) * position`
([transformation guide](./transforms/README.md)).

### Phase, amplitude, and frequency
The phase is the input to a periodic function such as sine; amplitude scales
its output, and frequency describes how quickly its phase changes. In the
[ripple shader](./interactive/interact_5/frag.glsl),
`A * sin(k * distance - omega * time)` has amplitude `A`, angular spatial
frequency `k`, and angular time frequency `omega`. For positive `k` and
`omega`, its fixed-phase bands travel outward at `omega / k`.

### Point light
A light with a position in space that illuminates surfaces in different directions depending on their locations. The deferred-lighting shader computes a direction and distance from each fragment to each point light ([`gbuffer_5/frag.glsl`](./g_buffer/gbuffer_5/frag.glsl)).

**Direction and distance:** `toLight = p_light - p_surface`, `d = ||toLight||`, and `L = toLight/d`.

### Point primitive
A primitive represented by a single vertex. When the host draws points,
`gl_PointSize` requests their screen-space size in pixels, subject to the
implementation's supported range. The [particle shader](./particles/particle_2/vert.glsl)
requests `2.0`; its fragment shader does not mask the point into a circle.

### Procedural mesh
Geometry built by code rather than loaded as a pre-authored mesh asset. `scene.ts` constructs a cube by creating and appending six quads ([`scene.ts`](./procedural_mesh_basics/procedural_mesh_7/scene.ts)).

### Pseudo-random hash
A deterministic function that maps a seed to a value that appears random. The
[particle shaders](./particles/particle_2/vert.glsl) use a sine-based hash of
position; identical seeds produce identical values in the same execution
environment. Its distribution and exact results across GPUs are not
guaranteed, and it is not suitable for cryptography.

## R

### Radiance
The incoming light intensity used in a lighting calculation. The PBR shader forms a simple light radiance value by multiplying light color by intensity ([`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

**Project approximation:** `radiance = lightColor · intensity`.

### Rasterization
The stage that converts projected primitives, such as triangles, into fragments covering screen pixels. It interpolates shader outputs such as UV coordinates across each primitive.

### Reflection vector
A direction obtained by reflecting the view ray around a surface normal. The reflection and PBR shaders use GLSL's `reflect` function to look up an approximate environment color ([`light_6/frag.glsl`](./materials/light_6/frag.glsl), [`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

**Formula:** `R = I - 2(N·I)N`; for the camera-to-surface incident direction `I = -V`, this becomes `R = reflect(-V, N)`.

### Rotation
A transform that turns points and directions around an axis while preserving
distances. GLSL trigonometric functions use radians; matrix constructor
values are filled by columns. The [transform 2 Y rotation](./transforms/transform_2/vert.glsl)
uses `x' = cos(a)*x - sin(a)*z` and `z' = sin(a)*x + cos(a)*z`. In a
conventional right-handed basis it rotates by `-a`; apparent screen direction
depends on the camera. See the [transformation guide](./transforms/README.md)
for X and illustrative Z rotations.

### Roughness
A material parameter describing the spread of microscopic surface orientations. Lower roughness produces sharper, narrower specular highlights; higher roughness produces broader, blurrier highlights ([`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

**Use in this project's GGX model:** `a = roughness²` and `a² = roughness⁴`; these values shape the distribution term. `roughness` is normally clamped to a valid range such as `[0,1]`.

## S

### Sampler / texture sampler
A shader uniform representing a texture resource. GLSL's `texture` function samples the resource at specified UV coordinates ([`procedural_mesh_7/frag.glsl`](./procedural_mesh_basics/procedural_mesh_7/frag.glsl)).

**Sampling notation:** `color = texture(sampler, uv)`, where `uv` selects the texture location.

### Scale
A transform that multiplies coordinates along one or more axes. The
[animated scale shader](./transforms/transform_6/vert.glsl) uses the uniform
factor `1 + 0.5*sin(u_time)`, ranging from `0.5` to `1.5`. Zero scale
collapses an axis; a negative scale reflects it and can affect face winding.

### Scanline
A horizontal band used as a visual effect. The
[scanline shader](./uv/uv_4/frag.glsl) modulates texture brightness using a
sine of screen Y and time. Its coefficient `100.0` is in radians per
normalized vertical unit, giving about 15.9 complete cycles per unit.

### Screen-space coordinates
Coordinates describing a location in the framebuffer or viewport rather than
on an object's surface. The scanline example divides `gl_FragCoord.xy` by
resolution; unlike mesh UVs, these coordinates follow the rendered screen.
Coordinate origin, framebuffer size, and viewport offset must be consistent.

### Schlick approximation
A compact approximation of the Fresnel reflectance curve, often expressed with a fifth power of one minus the view/reflection cosine. It is implemented in both the simple reflection and PBR examples ([`light_6/frag.glsl`](./materials/light_6/frag.glsl), [`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

**Formula:** `F = F₀ + (1 - F₀)(1 - cos θ)⁵`, applied component-wise for vector reflectance.

### Specular reflection
Mirror-like reflection that forms highlights and environment reflections. In the PBR shader, it is computed using the Cook-Torrance microfacet terms.

### Smith geometry
A method for combining masking/shadowing terms for both the view and light directions in a microfacet BRDF. The project's `geometrySmith` multiplies two Schlick-GGX terms ([`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

**Project formula:** `G = G₁(N·V, r) G₁(N·L, r)`, where `G₁(x,r) = x / (x(1-k)+k)` and `k = (r+1)²/8`.

## T

### Taper
A deformation that changes a cross-section's size along an axis. The
[taper shader](./transforms/transform_8/vert.glsl) uses local Z to scale Y
about `y = 0`: `y' = y * (1 + 0.95*z)`. Its factor is zero near
`z = -1.0526` and negative below that; it is not clamped.

### Tangent space
A coordinate frame attached to a surface, commonly made from tangent, bitangent, and normal directions. It is useful for interpreting height maps or normal maps independently of the object's world orientation. The POM shader converts the view direction into this frame ([`parallax_2/frag.glsl`](./materials/parallax_2/frag.glsl)).

**Basis conversion:** For an orthonormal frame `(T, B, N)`, `v_tangent = (v·T, v·B, v·N)`.

### Texture
An image or sampled data resource used by a shader. The project uses textures for albedo, depth, normals, and height, and samples them with UV coordinates.

### Texture gradients (`dFdx`, `dFdy`, `textureGrad`)
Derivatives that describe how texture coordinates change across neighboring fragments. They help the GPU choose an appropriate mip level and filtering footprint. The POM shader supplies gradients from the original UVs when sampling at its shifted coordinates ([`parallax_2/frag.glsl`](./materials/parallax_2/frag.glsl)).

**Conceptual derivatives:** `dFdx(uv) ≈ uv(x+1,y)-uv(x,y)` and `dFdy(uv) ≈ uv(x,y+1)-uv(x,y)` over neighboring fragments.

### Texture LOD (Level of Detail)
A texture mipmap level selected for sampling. `textureLod` explicitly chooses a level; the height-sampling helper in the POM shader requests level zero ([`parallax_2/frag.glsl`](./materials/parallax_2/frag.glsl)).

### Threshold mask
A binary value selected by comparing an input with a cutoff. GLSL's
`step(edge, x)` returns `0` below the edge and `1` at or above it. The
[image transition](./image_transitions/image_transition_1/frag.glsl) uses the
sampled red channel and time-based progress to mask texture alpha; blending
configuration is still required to display transparency.

### Tone mapping
A transform that compresses HDR lighting values into a displayable LDR range. The PBR shader uses `color / (color + 1)` before gamma correction ([`light_7/frag.glsl`](./materials/light_7/frag.glsl)).

**Project formula:** `C_tone = C_hdr / (C_hdr + 1)`, applied component-wise for nonnegative `C_hdr`.

### Transformation order
The order in which scale, rotation, translation, and camera matrices act on a
position. With the column-vector convention used in the
[transform guide](./transforms/README.md), `T * R * S * p` applies scale first,
then rotation, then translation. Changing the order generally changes the result.

### Triangle winding
The clockwise or counterclockwise order of triangle vertices as seen from one side. It controls front-face determination and can be reversed to render the opposite side ([`scene.ts`](./procedural_mesh_basics/procedural_mesh_7/scene.ts)).

**Visual:** See the CCW and CW triangle diagrams under [Face winding](#face-winding). Reversing `(0, 1, 2)` to `(0, 2, 1)` reverses the winding.

### Twist
A deformation that rotates cross-sections by an angle that varies along an
axis. The [twist shader](./transforms/transform_10/vert.glsl) rotates XZ by
`position.y * u_time`. Its normal rotation is approximate: it does not account
for the angle's variation with height.

## U

### Uniform
A shader input whose value is constant across the vertices or fragments of a draw call. Matrices, camera positions, light settings, and texture samplers are commonly supplied as uniforms.

### UV coordinates
Two-dimensional texture coordinates that map a point on a mesh to a location in a texture. The procedural cube assigns a `[0, 1]` square to each face, and the fragment shader samples its texture at the interpolated UV ([`scene.ts`](./procedural_mesh_basics/procedural_mesh_7/scene.ts), [`procedural_mesh_7/frag.glsl`](./procedural_mesh_basics/procedural_mesh_7/frag.glsl)).

**Screen-to-texture mapping:** For normalized UV `(u,v) ∈ [0,1]²`, the texture is sampled at that normalized location; the procedural cube maps each face's four corners to `(0,0)`, `(1,0)`, `(1,1)`, and `(0,1)`.

### UV seam
A location where neighboring or coincident surface points have different UV
coordinates. The [lathe mesh](./procedural_mesh_basics/lathe_1/scene.ts)
duplicates the start and end of each ring so the seam can have U values `0`
and `1` while the surface wraps around.

## V

### Varying
A value passed from a vertex shader to a fragment shader and interpolated across the primitive. In GLSL ES 3.00, vertex outputs and fragment inputs use `out` and `in` declarations, respectively; names and types must match between stages.

**Interpolation:** Default smooth interpolation is perspective-correct. For
screen-space barycentric weights `λᵢ`, vertex clip-space values `wᵢ`, and
vertex values `vᵢ`, `v = (Σ λᵢ vᵢ / wᵢ) / (Σ λᵢ / wᵢ)`. With equal `wᵢ`
this reduces to the usual linear weighted sum. `flat` outputs bypass
interpolation and use the provoking vertex's value.

### Vertex
A mesh point carrying attributes such as position, normal, color, and UV coordinates. Vertex shaders transform these points before the GPU rasterizes the mesh.

### Vertex shader
A programmable GPU stage that processes each vertex, transforms its position, and passes per-vertex values to later stages ([`procedural_mesh_7/vert.glsl`](./procedural_mesh_basics/procedural_mesh_7/vert.glsl)).

### View space
A coordinate space relative to the camera. The view matrix transforms world-space positions into this space before projection.

## W

### World space
A coordinate system shared by objects in the scene, independent of an individual object's local coordinates. Lighting calculations that compare world-space positions and directions must use world-space normals and vectors consistently.

**Transform:** `p_world = M_world · (p_local, 1)` in homogeneous coordinates; a direction uses `w = 0` so translation does not affect it.

### World matrix
A matrix that transforms local/object-space positions into world space. Per-instance world matrices are assembled from four `vec4` attributes in the procedural-mesh vertex shader ([`procedural_mesh_7/vert.glsl`](./procedural_mesh_basics/procedural_mesh_7/vert.glsl)).
