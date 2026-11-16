# Step-by-Step Explanation of the Interactive Ripple Shaders

This lesson uses a vertex shader, [`vert.glsl`](./vert.glsl), to pass texture
coordinates through the graphics pipeline, and a fragment shader,
[`frag.glsl`](./frag.glsl), to create a mouse-centered ripple effect while
sampling a texture.

Try the [interactive ripple demo](./wave-demo.html) to move the ripple center,
adjust its parameters, and inspect the wave and falloff profiles visually.

The repository contains the shader code, but not the host renderer that loads
the texture, supplies the mouse position and time, or binds the vertex
attributes. Those values must be provided by the application using the shaders.

## 1. Vertex shader: pass position and UV coordinates through

### Step 1: Declare the GLSL version

```glsl
#version 300 es
```

This selects GLSL ES 3.00, the shader language version used by WebGL 2. In this
version, shader inputs and outputs are declared with `in` and `out`.

### Step 2: Declare the vertex inputs

```glsl
in vec4 position;
in vec2 uv;
```

These are per-vertex attributes supplied by the renderer:

- `position` is the vertex position. It has four components because it is
  already represented as a homogeneous position.
- `uv` is the vertex's 2D texture coordinate. It identifies which part of the
  texture is associated with that vertex.

The application must bind vertex data to attributes with these names (or link
the names to the corresponding attribute locations).

### Step 3: Declare the varying output

```glsl
out vec2 v_uv;
```

`v_uv` carries a UV coordinate from the vertex shader to the fragment shader.
The rasterizer interpolates it across each triangle, so each fragment gets a
coordinate corresponding to its position on the rendered surface.

### Step 4: Set the clip-space position and forward the UV

```glsl
gl_Position = position;
v_uv = uv;
```

`gl_Position` is the required position output used by clipping and
rasterization. This shader assigns `position` directly; it does not apply world,
view, or projection matrices. That means the supplied positions must already be
in the coordinate space expected for rendering (typically clip space), or the
host must otherwise arrange the geometry for this simple pass-through shader.

The UV is also passed through unchanged. The fragment shader then uses the
interpolated `v_uv` to sample the texture and measure distance from the mouse.

## 2. Fragment shader: calculate and display the ripple

The fragment shader runs for each rasterized fragment and writes its final
color. In this lesson that color is a mixture of a dark background and a
texture sample whose coordinates have been offset by animated waves.

### Step 1: Select shader version and floating-point precision

```glsl
#version 300 es
precision mediump float;
```

The version matches the vertex shader. `mediump` requests medium precision for
floating-point calculations. It is commonly sufficient for this screen-space
effect, though available precision can vary by device.

### Step 2: Declare inputs, uniforms, and the color output

```glsl
uniform sampler2D u_texture;
uniform vec2 u_mousePosition;
uniform float u_time;
in vec2 v_uv;
out vec4 fragColor;
```

- `u_texture` is the 2D image to sample. The renderer must bind a texture to the
  corresponding sampler unit.
- `u_mousePosition` is the mouse location used as the ripple center. Since it
  is compared with `v_uv`, the two values need to use the same coordinate
  system. In this shader that means normalized texture/UV coordinates, not raw
  pixel coordinates.
- `u_time` drives animation. The host should update it over time; the code
  treats its value as a continuously increasing time quantity.
- `v_uv` is the interpolated coordinate passed from the vertex shader.
- `fragColor` is the RGBA color written for this fragment.

The host must convert mouse coordinates into the same normalized UV convention
as the mesh's UVs. For example, pixel coordinates can be divided by the
rendered area's width and height, but the exact mapping (including whether an
axis must be flipped) depends on the application's event and texture setup.
See the repository's [coordinate conventions](../../COORDINATE_CONVENTIONS.md)
for general UV guidance.

### Step 3: Measure distance from the mouse and set the effect radius

```glsl
float dist = distance(v_uv, u_mousePosition);
float radius = 0.4;
```

`distance(a, b)` returns the Euclidean distance between two 2D points. Because
the values are UV coordinates, this distance is measured in UV units. A radius
of `0.4` therefore defines a circular region around the mouse in that
coordinate space; it is not a fixed number of screen pixels.

### Step 4: Define the fallback background color

```glsl
vec4 backgroundColor = vec4(0.1, 0.1, 0.1, 1.0);
```

This is a very dark gray with fully opaque alpha. It is the first color in the
final blend. The output remains opaque because both this color and the sampled
texture are blended into `fragColor`.

### Step 5: Configure the animated waves

```glsl
float waveSpeed = 2.0;
float waveFrequency = 8.0;
float waveAmplitude = 0.1;
```

These constants control the wave pattern:

- `waveSpeed` controls how quickly the pattern changes as `u_time` advances.
- `waveFrequency` controls how quickly the wave phase changes with distance,
  and thus how closely spaced the rings are.
- `waveAmplitude` scales the main wave's numeric range.

The shader combines three sine waves with different frequencies, speeds, and
amplitudes:

```glsl
float wave1 = sin(dist * waveFrequency - u_time * waveSpeed)
            * waveAmplitude;
float wave2 = sin(dist * waveFrequency * 0.5 - u_time * waveSpeed * 0.7)
            * waveAmplitude * 0.7;
float wave3 = sin(dist * waveFrequency * 0.3 - u_time * waveSpeed * 0.5)
            * waveAmplitude * 0.5;
```

Each sine has the form `A * sin(k * dist - omega * u_time)`. The sine's input
is its phase, measured in radians:

| Wave | Spatial coefficient `k` | Time coefficient `omega` | Amplitude `A` |
| --- | --- | --- | --- |
| `wave1` | `waveFrequency` | `waveSpeed` | `waveAmplitude` |
| `wave2` | `0.5 * waveFrequency` | `0.7 * waveSpeed` | `0.7 * waveAmplitude` |
| `wave3` | `0.3 * waveFrequency` | `0.5 * waveSpeed` | `0.5 * waveAmplitude` |

These coefficients affect different parts of the motion:

1. **Distance creates rings.** `dist` is the UV-space distance from the mouse,
   so every point on a circle around the mouse has the same phase at a given
   time. As distance changes, the phase changes by `k` radians per UV unit.
   One full sine cycle spans `2 * pi / k` UV units; a larger `k` therefore
   makes the rings closer together.
2. **Time moves the rings.** At a fixed point, the phase changes by
   `-omega` radians per unit of `u_time`. To follow a fixed phase, solve
   `k * dist - omega * u_time = constant`. This gives an outward radial speed
   of `omega / k` UV units per unit of `u_time`. The minus sign is why the
   pattern travels outward; changing it to plus would make it travel inward.
3. **Amplitude controls height, not speed.** Since `sin` ranges from `-1` to
   `1`, each wave ranges from `-A` to `+A`. The second and third waves are
   smaller contributions, at 70% and 50% of the main amplitude.
4. **Adding different waves changes the shape.** Their peaks and troughs do
   not usually line up. When they have the same sign they reinforce each
   other; when they have opposite signs they partially cancel. This overlap
   makes the combined pattern less regular than a single sine wave.

For the shader's defaults (`waveFrequency = 8`, `waveSpeed = 2`), the first
wave travels at `2 / 8 = 0.25` UV units per time unit. The second and third
travel at `(0.7 * 2) / (0.5 * 8) = 0.35` and
`(0.5 * 2) / (0.3 * 8) ~= 0.417` UV units per time unit. Although their time
coefficients are smaller, their spatial coefficients are reduced even more,
so their rings move outward faster. Their full-cycle distances are about
`0.785`, `1.571`, and `2.618` UV units respectively; this explains why a small
radius may show only part of a cycle from some of the waves.

### Step 6: Add the waves together

```glsl
float combinedWave = wave1 + wave2 + wave3;
```

This produces one signed scalar wave value for the current fragment. It is
later used both to offset the texture coordinates and to determine how strongly
the texture contributes to the final color.

### Step 7: Fade the effect with distance

```glsl
float falloff = 1.0 - smoothstep(0.0, radius, dist);
```

`smoothstep(0.0, radius, dist)` transitions smoothly from `0` near the mouse to
`1` at and beyond the radius. Subtracting it from `1` reverses the transition:
`falloff` is near `1` at the center and fades to `0` as the distance reaches
the radius. This avoids a hard circular edge in the wave's contribution to
color blending.

The nearby commented TODO lines show that falloff was an intended part of the
effect; the active expression now computes it.

### Step 8: Turn the wave into a texture-coordinate offset

```glsl
vec2 waveOffset = vec2(combinedWave * 0.02, combinedWave * 0.02);
```

The scalar wave is scaled by `0.02` and placed in both components of a 2D
offset. The texture sample is consequently shifted along the diagonal direction
where U and V change together. This is a simple distortion, not a radial
outward displacement: both axes receive the same signed shift regardless of
the fragment's direction from the mouse.

The offset itself is not multiplied by `falloff`. Thus the texture coordinates
are displaced wherever the shader samples the texture, even outside the ripple
radius. The falloff affects the later color blend, not this coordinate
calculation.

### Step 9: Sample the texture at the displaced coordinate

```glsl
vec4 textureColor = texture(u_texture, v_uv + waveOffset);
```

`texture` reads the image at the fragment's interpolated UV plus the wave
offset. Changing the lookup coordinate makes the visible image appear to
distort. How samples outside the texture's `[0, 1]` UV range behave depends on
the texture's wrapping settings supplied by the host.

### Step 10: Calculate wave intensity

```glsl
float waveIntensity = abs(combinedWave) * falloff;
```

`abs` removes the wave's sign so positive and negative phases both contribute
to the blend strength. Multiplying by `falloff` reduces that contribution
toward the edge of the radius. At and beyond the radius, `waveIntensity` is
zero.

### Step 11: Blend background and texture

```glsl
fragColor = mix(backgroundColor, textureColor, waveIntensity + 0.3);
```

`mix(a, b, t)` interpolates from `a` to `b`: when `t` is `0`, the result is
`a`; when `t` is `1`, it is `b`. Here `t` is `waveIntensity + 0.3`, so the
texture contributes at least 30% even where the ripple's falloff has reached
zero. The result outside the radius is therefore not a pure background color;
it is a 30% texture / 70% background mixture.

With the current amplitudes, the absolute combined wave is at most
`0.1 + 0.07 + 0.05 = 0.22`; `falloff` is between zero and one. The mix factor
therefore stays between `0.3` and `0.52`, within the usual `mix` interpolation
range `[0, 1]`.

## 3. How the shaders work together

1. The host supplies vertices, UVs, a texture, a mouse position, and time.
2. The vertex shader writes each position to `gl_Position` and passes UVs to
   the rasterizer.
3. The rasterizer interpolates the UVs across each triangle.
4. The fragment shader measures each interpolated UV's distance from the mouse.
5. Three animated sine waves are combined, used to shift the texture lookup,
   and attenuated by a distance-based falloff for color blending.
6. The shader blends the sampled texture with a dark background and writes the
   result to `fragColor`.

## 4. Practical checks when using the effect

- Ensure `u_mousePosition` is in the same normalized coordinate system and
  orientation as `v_uv`; a pixel/UV mismatch can make the center appear in the
  wrong place or scale.
- Update `u_time` each frame to animate the rings.
- Confirm the texture is bound to `u_texture` and its wrapping mode is
  appropriate for the offset samples.
- Remember that `radius` is measured in UV distance, so its apparent pixel
  radius can vary with the rendered area's aspect ratio.
- If the desired result is a pure background outside the ripple, the fixed
  `+ 0.3` blend contribution would need to vary with distance; as written, it
  deliberately or unintentionally leaves some texture visible everywhere.
