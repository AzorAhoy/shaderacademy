# Step-by-Step Explanation of `frag.glsl`

This folder contains a fragment shader for a deferred-lighting pass. It reads surface information stored in G-buffer textures, reconstructs the world-space position of each visible pixel, applies ambient and point-light diffuse illumination, and writes the shaded color.

The shader expects the preceding geometry pass to provide:

- `gBufferAlbedo`: the surface's base color, with alpha zero marking pixels where no geometry was drawn.
- `gBufferDepth`: the depth-buffer value for each pixel.
- `gBufferNormal`: the surface normal encoded into the `[0, 1]` color range.

## 1. Select the shader language and precision

```glsl
#version 300 es
precision highp float;
```

`#version 300 es` selects GLSL ES 3.00, used by WebGL 2. `highp` requests high-precision floating-point arithmetic, which is useful for depth reconstruction and lighting calculations.

## 2. Receive the screen coordinate for this fragment

```glsl
in vec2 vUV;
```

`vUV` is interpolated from the vertex shader. In this post-processing pass, it should identify the corresponding location in each G-buffer texture, typically with both components in the `[0, 1]` range. The vertex shader that provides `vUV` is not in this folder.

All three G-buffer textures must use compatible dimensions and texture-coordinate orientation. Otherwise, the shader could combine the color, depth, and normal from different pixels.

## 3. Declare the G-buffer inputs and camera matrix

```glsl
uniform sampler2D gBufferDepth;
uniform sampler2D gBufferNormal;
uniform sampler2D gBufferAlbedo;
uniform mat4 u_inverseViewProjection;
```

The three `sampler2D` uniforms reference textures produced by the geometry pass:

- `gBufferDepth` provides the stored depth value.
- `gBufferNormal` provides the encoded surface normal.
- `gBufferAlbedo` provides the base surface color and the alpha marker used to identify empty pixels.

`u_inverseViewProjection` is the inverse of the camera's view-projection matrix. It converts a clip-space position back into world space. It must match the camera and projection used when the G-buffer was rendered.

## 4. Declare the final color output

```glsl
out vec4 fragColor;
```

This shader writes one RGBA color for each output fragment. Unlike the geometry pass, this pass does not write new depth, normal, or albedo attachments.

## 5. Define the scene's point lights

```glsl
const int NUM_LIGHTS = 3;
const vec3 LIGHT_POSITIONS[NUM_LIGHTS] = vec3[](
    vec3(5.0, -1.5, -2.0),
    vec3(-2.0, -1.5, 5.0),
    vec3(-3.0, 1.0, -3.0)
);
const vec3 LIGHT_COLORS[NUM_LIGHTS] = vec3[](
    vec3(1.6, 0.4, 0.3),
    vec3(0.3, 1.4, 0.5),
    vec3(0.4, 0.6, 1.8)
);
```

The shader uses three fixed point lights. Each light has:

- A world-space position in `LIGHT_POSITIONS`.
- An RGB color/intensity in `LIGHT_COLORS`.

Some color components exceed `1.0`, making those channels more intense than a unit-valued color. These constants are hard-coded, so changing the light setup requires editing the shader or changing its design to use uniforms.

## 6. Sample the surface's albedo

```glsl
vec4 albedo = texture(gBufferAlbedo, vUV);
```

The shader samples the albedo texture at this fragment's UV coordinate. The RGB channels are used later as the surface's base color. Alpha is used immediately to detect pixels that contain no rendered geometry.

## 7. Handle pixels with no geometry

```glsl
if (albedo.a == 0.0) {
    fragColor = vec4(0.05, 0.05, 0.07, 1.0);
    return;
}
```

An alpha value of zero is treated as the G-buffer clear value: there is no surface at this pixel to light. The shader writes a very dark blue-gray background color and returns early, avoiding depth reconstruction and lighting work.

This relies on the geometry pass clearing the albedo attachment to alpha zero for uncovered pixels and writing a nonzero alpha for geometry. The comparison is an exact equality check, so the clear and write conventions must be consistent.

## 8. Read depth and reconstruct the world-space position

```glsl
float depth = texture(gBufferDepth, vUV).r;
vec4 clipPos = vec4(vUV * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
vec4 worldPos = u_inverseViewProjection * clipPos;
vec3 position = worldPos.xyz / worldPos.w;
```

The reconstruction happens in four stages:

1. **Read stored depth.** The red channel is sampled from `gBufferDepth`. The geometry pass stores a conventional depth value in `[0, 1]`.
2. **Convert screen coordinates to NDC.** `vUV * 2.0 - 1.0` maps x and y from `[0, 1]` to `[-1, 1]`. Similarly, `depth * 2.0 - 1.0` maps depth to NDC z in `[-1, 1]`.
3. **Build the clip/NDC position.** These three coordinates and a homogeneous `w` of `1.0` form `clipPos`.
4. **Unproject and divide by w.** Multiplication by the inverse view-projection matrix returns a homogeneous world-space position. Dividing by its `w` component performs the perspective divide, yielding `position` in world coordinates.

The depth convention, UV orientation, inverse matrix, and camera used here must agree with those used in the geometry pass. A mismatch can shift or distort reconstructed positions, which in turn makes the lighting appear incorrect.

## 9. Read and decode the surface normal

```glsl
vec3 normal = normalize(texture(gBufferNormal, vUV).rgb * 2.0 - 1.0);
```

The normal texture stores a signed normal remapped into a nonnegative range, usually by encoding it as `normal * 0.5 + 0.5`. This shader reverses that mapping with `rgb * 2.0 - 1.0`, converting each channel from `[0, 1]` back to `[-1, 1]`. `normalize` ensures the resulting direction has unit length.

The normal must be encoded in the same coordinate space expected by the lighting calculation. Because each light position and reconstructed surface position are in world space, this calculation expects world-space normals.

## 10. Add a small ambient-light baseline

```glsl
vec3 color = albedo.rgb * 0.04;
```

The surface begins with a dim ambient term: 4% of its albedo. This provides a baseline so surfaces not facing any point light are not completely black. It is a simple constant approximation; it does not depend on direction, distance, or scene occlusion.

## 11. Accumulate diffuse light from each point light

```glsl
for (int i = 0; i < NUM_LIGHTS; i++) {
    vec3 toLight = LIGHT_POSITIONS[i] - position;
    float dist = length(toLight);
    float diff = max(dot(normal, toLight / dist), 0.0);
    float attenuation = 1.0 / (1.0 + 0.03 * dist * dist);
    color += albedo.rgb * LIGHT_COLORS[i] * diff * attenuation;
}
```

The loop evaluates each of the three lights and adds its contribution:

1. **Find the direction and distance to the light.** Subtract the surface's world-space position from the light's position. `length(toLight)` gives the distance.
2. **Normalize the light direction.** `toLight / dist` points from the surface toward the light and has unit length.
3. **Calculate Lambert diffuse response.** `dot(normal, lightDirection)` is large when the surface faces the light and negative when it faces away. `max(..., 0.0)` removes negative values, so a light cannot contribute diffuse illumination to the back side of a surface.
4. **Reduce intensity with distance.** `1.0 / (1.0 + 0.03 * dist * dist)` dims the light as distance increases. The coefficient `0.03` controls how quickly it fades.
5. **Add the contribution.** The base color is multiplied by the light's color, the diffuse response, and the attenuation. Each light's contribution is added to the accumulated `color`.

This is a basic diffuse model: it does not calculate specular highlights, shadows, or physically based material properties. It also assumes a fragment is not exactly at a light's position, because dividing by a zero distance would make the light direction undefined.

## 12. Write the final shaded color

```glsl
fragColor = vec4(color, 1.0);
```

The accumulated RGB lighting result is written as the fragment color, with alpha set to fully opaque. The output combines the ambient baseline and the diffuse contributions of all three lights.

## Overall flow

For each screen pixel, the shader checks whether the G-buffer contains a surface. If it does, it reads that surface's depth, normal, and albedo; reconstructs the world position; evaluates the three point lights; and writes the resulting shaded color. This separates geometry rendering from lighting: the geometry pass records surface data once, and this pass uses that data to calculate illumination.
