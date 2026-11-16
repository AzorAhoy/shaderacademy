# Step-by-Step Explanation of the Animated Scanline Shaders

This example uses a [vertex shader](./vert.glsl) to pass positions through to
the graphics pipeline, and a [fragment shader](./frag.glsl) to sample a texture
and darken it with moving horizontal scanlines.

The host application must supply the geometry, texture, framebuffer
resolution, time, and draw call. The shaders do not load an image or advance
time by themselves.

## 1. Overview

1. The vertex shader passes each input position directly to `gl_Position`.
2. The rasterizer generates fragments for the resulting geometry.
3. The fragment shader converts each fragment's pixel position to normalized
   screen coordinates.
4. It uses the vertical coordinate and time to calculate a sine-wave
   brightness multiplier.
5. It samples the texture at the screen coordinate, multiplies the sampled
   RGB by the scanline multiplier, and writes an opaque color.

The effect is screen-space: it uses the fragment's framebuffer position, not
the mesh's interpolated UVs.

## 2. Vertex shader

### Step 1: Select the shader language version

```glsl
#version 300 es
```

This selects GLSL ES 3.00, the language version used by WebGL 2.

### Step 2: Declare the vertex inputs

```glsl
in vec4 position;
in vec2 uv;
```

The host supplies these per-vertex attributes:

- `position` is a four-component homogeneous position.
- `uv` is a two-dimensional texture coordinate.

The shader does not apply world, view, or projection matrices, so the position
must already be suitable for direct use as a clip-space position. A full-screen
quad with appropriate clip-space positions is one possible host setup.

### Step 3: Declare the varying output

```glsl
out vec2 v_uv;
```

This declares a texture coordinate to pass to the next pipeline stage. For
triangles, varying values are normally interpolated across the primitive.
However, the current fragment shader does not declare or use `v_uv`, so this
output and the `uv` attribute do not determine the sampled texture coordinate
and may be optimized away.

### Step 4: Pass the position and UV through

```glsl
gl_Position = position;
v_uv = uv;
```

`gl_Position` is the required clip-space output used for clipping and
rasterization. The UV is forwarded unchanged, although the fragment shader
uses a separate screen-space coordinate instead.

## 3. Fragment shader

### Step 1: Declare the language version and precision

```glsl
#version 300 es
precision highp float;
```

The version matches the vertex shader. `highp` requests high-precision
floating-point arithmetic, useful for fragment coordinates and the animated
sine calculation.

### Step 2: Declare uniforms and the output

```glsl
uniform sampler2D u_texture;
uniform float u_time;
uniform vec2 u_resolution;
out vec4 fragColor;
```

- `u_texture` is the 2D image to sample. The host must bind the image to the
  sampler's texture unit.
- `u_time` controls animation. The host must update it over time.
- `u_resolution` is the width and height in framebuffer pixels used to
  normalize `gl_FragCoord.xy`. Both components must be nonzero.
- `fragColor` is the output RGBA color.

### Step 3: Calculate normalized screen coordinates

```glsl
vec2 uv = gl_FragCoord.xy / u_resolution;
```

`gl_FragCoord.xy` gives the fragment's window coordinates in framebuffer
pixels. Dividing by the framebuffer width and height maps positions across a
zero-origin, full-frame viewport to approximately `[0, 1]` on each axis. Pixel
centers ordinarily lie inside, rather than exactly on, the endpoints.

In the usual WebGL/OpenGL convention, window X increases to the right and Y
increases upward from the lower-left origin. For example, a fragment near the
center of an 800 × 600 framebuffer has coordinates near `(400, 300)` and a
normalized `uv` near `(0.5, 0.5)`.

The code does not subtract a viewport origin. For a viewport offset within a
larger framebuffer, these are normalized framebuffer coordinates rather than
viewport-local coordinates. If viewport-local mapping is required, the host
or shader must account for that offset and use the matching dimensions.

The texture's visual orientation also depends on how the host provides and
uploads the image; normalized coordinates alone do not establish which image
row appears at the top. See the [coordinate conventions](../../COORDINATE_CONVENTIONS.md).

### Step 4: Set the scanline controls

```glsl
float scanlineFrequency = 100.0;
float scanlineIntensity = 0.2;
```

`scanlineFrequency` controls how quickly the sine phase changes as `uv.y`
changes. Despite the source comment saying “Number of scanlines,” `100.0` is
an angular spatial coefficient in radians per normalized vertical unit, not
exactly 100 complete lines.

One sine cycle spans `2 * pi / 100`, or about `0.0628` normalized vertical
units. Across a full unit of vertical UV space that is approximately
`100 / (2 * pi) = 15.9` cycles. The visible number of bands can vary with
coverage and where the cycles begin and end.

`scanlineIntensity` controls how strongly the sine pattern darkens the
texture. Its exact effect is calculated by `mix` in step 7.

### Step 5: Move the pattern over time

```glsl
float ySpeed = 0.2;
float movingY = uv.y + u_time * ySpeed;
```

The shader offsets the vertical coordinate by `0.2` normalized vertical
units per unit of `u_time`. At time zero, `movingY` equals `uv.y`; at time
`1`, it is `uv.y + 0.2`.

This is a phase offset, not a texture-coordinate displacement: the texture is
still sampled at the original `uv`. With increasing time, a fixed sine phase
satisfies `uv.y + u_time * ySpeed = constant`, so the bands travel toward
decreasing screen Y. Under the usual lower-left-origin convention that is
downward, at `0.2` normalized vertical units per time unit. If the host uses
seconds, that is 20% of the normalized height per second.

### Step 6: Generate the sine wave

```glsl
float scanline = sin(movingY * scanlineFrequency) * 0.5 + 0.5;
```

The sine's input is its phase in radians. All fragments on the same screen row
have the same `uv.y`, so they receive the same scanline value, forming
horizontal bands.

`sin` returns values from `-1` to `1`. Multiplying by `0.5` and adding `0.5`
maps that range to `[0, 1]`:

| Sine value | Scanline before intensity |
| --- | --- |
| `-1` | `0` |
| `0` | `0.5` |
| `1` | `1` |

With the current settings, the phase at a fixed pixel changes at
`100 * 0.2 = 20` radians per time unit. The pattern repeats there after
`2 * pi / 20`, or about `0.314` time units.

### Step 7: Reduce the darkening strength

```glsl
scanline = mix(1.0, scanline, scanlineIntensity);
```

`mix(a, b, t)` calculates `a * (1.0 - t) + b * t`. With intensity `0.2`,
the multiplier is `0.8 + 0.2 * scanline`:

| Raw scanline | Final multiplier |
| --- | --- |
| `0` | `0.8` |
| `0.5` | `0.9` |
| `1` | `1.0` |

Thus the default bands range from no darkening to 20% darkening. An intensity
of `0` would yield `1` everywhere; an intensity of `1` would use the full
`[0, 1]` sine range. The nearby TODO is a lesson prompt; the active code
already performs the adjustment.

### Step 8: Sample the texture

```glsl
vec3 textureColor = texture(u_texture, uv).xyz;
```

`texture` samples the image using the normalized **screen-space** `uv`
calculated in step 3. `.xyz` extracts the red, green, and blue channels and
ignores the sampled alpha. Texture filtering, wrapping, and image orientation
are determined by the host's texture setup.

Because the shader uses screen coordinates instead of the vertex shader's
`v_uv`, changing the mesh UVs does not change this lookup. On a partial-screen
primitive, the sampled region corresponds to that primitive's screen
position rather than automatically spanning the whole texture.

### Step 9: Apply the scanlines and write the color

```glsl
fragColor = vec4(textureColor * scanline, 1.0);
```

Multiplying the texture RGB by the scanline multiplier darkens all three
channels equally. With the default intensity, a sampled RGB of
`(0.5, 0.25, 0.75)` at the darkest point becomes
`(0.4, 0.2, 0.6)`. At a multiplier of `1`, the RGB is unchanged.

The output alpha is explicitly `1.0`, regardless of the texture's alpha. The
nearby TODO describes the blend; the active line already applies it.

## 4. Practical considerations

- **Use the right resolution:** supply nonzero framebuffer dimensions in
  pixels, not necessarily CSS dimensions. Update them when the render target
  resizes.
- **Account for viewport offsets:** the current formula assumes normalized
  framebuffer coordinates; it does not produce viewport-local UVs for an
  offset viewport.
- **Update time:** the scanlines remain static unless the host changes
  `u_time`. Large time values can eventually reduce phase precision.
- **Understand the frequency:** `100.0` produces about 15.9 full cycles per
  normalized vertical unit, not 100. Very closely spaced bands can alias at
  low framebuffer resolutions.
- **Preserve transparency if needed:** this example ignores texture alpha and
  writes opaque output; a transparent effect would need different alpha and
  host blending behavior.
- **Screen UVs are not mesh UVs:** the vertex shader forwards `v_uv`, but
  the fragment shader does not use it. If the intent is to follow a surface's
  UV mapping instead, the shader would need a matching input and a different
  coordinate choice.
