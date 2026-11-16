# Particle 6: Texture Alpha Fading by World-Origin Distance

The [vertex shader](./vert.glsl) transforms geometry and forwards its world-space position and UV coordinates. The [fragment shader](./frag.glsl) samples a texture and reduces its alpha as that position moves farther from the world origin.

**Important:** The source comments describe camera distance, but the code uses `length(vPosition)`. Because `vPosition` is a world-space position, this is distance from `(0, 0, 0)`, not from the camera, unless the camera is at the world origin. Moving the camera alone does not change this distance for a fixed world-space point.

The host application must provide geometry, matrices, a texture, and the draw call. It must also configure blending if the alpha fade is intended to appear as transparency. The shaders do not create or animate particles themselves.

## 1. Overview

1. Transform each vertex from object space to world space and clip space.
2. Pass the world position and texture coordinates to the fragment shader.
3. Measure the interpolated world position's distance from the world origin.
4. Divide by the fixed maximum distance and clamp the result.
5. Invert that normalized distance to obtain a fade factor.
6. Sample the texture and multiply its alpha by the fade factor.

## 2. Vertex shader, step by step

### Step 1: Select the language and precision

```glsl
#version 300 es
precision highp float;
```

GLSL ES 3.00 is the shader language used by WebGL 2. `highp` requests high-precision floating-point calculations for positions and transformations.

### Step 2: Receive mesh attributes

```glsl
in vec3 position;
in vec3 normal;
in vec2 uv;
```

The host supplies an object-space position, object-space normal, and UV coordinate for each vertex. The normal is forwarded but unused by the current fragment shader. Active attributes and uniforms must be bound by the host; unused ones may be optimized away.

### Step 3: Receive the transformation matrices

```glsl
uniform mat4 world;
uniform mat4 worldView;
uniform mat4 worldViewProjection;
```

`world` maps object-space positions to world space. `worldViewProjection` maps them to clip space, conventionally using projection, view, and world in that order. `worldView` is declared but unused. The host must provide consistent active matrices.

### Step 4: Declare the outputs

```glsl
out vec3 vNormal;
out vec3 vPosition;
out vec2 v_uv;
```

These match the fragment inputs. `vPosition` carries world position and `v_uv` carries texture coordinates. For triangles, the rasterizer normally interpolates them perspective-correctly across the primitive. For a point primitive, the varying values come from its single vertex.

### Step 5: Transform the position and normal

```glsl
vec4 worldPos = world * vec4(position, 1.0);
vPosition = worldPos.xyz;
vNormal = normalize(mat3(world) * normal);
```

The `1.0` makes the object-space position a homogeneous point, allowing the world matrix to apply translation. `vPosition` receives the world-space `xyz`, which determines the fade in the fragment shader.

The normal is transformed and normalized but is not used in the fragment shader. The simple `mat3(world)` form works for rotations and uniform scaling; a non-uniform scale or shear generally requires an inverse-transpose normal matrix.

### Step 6: Forward UV and produce clip-space position

```glsl
v_uv = uv;
gl_Position = worldViewProjection * vec4(position, 1.0);
```

The UV is passed through unchanged. `gl_Position` gives the graphics pipeline the clip-space vertex position for clipping and rasterization. The camera affects where the geometry appears on screen, but the fade calculation uses the separately computed world position.

## 3. Fragment shader, step by step

### Step 1: Receive inputs

```glsl
in vec3 vNormal;
in vec3 vPosition;
in vec2 v_uv;

uniform vec3 lightPosition;
uniform vec3 lightColor;
uniform vec3 objectColor;
uniform float shininess;
uniform sampler2D u_texture;
```

`vPosition` supplies world-space position and `v_uv` supplies the texture coordinate. The host binds the texture to `u_texture`. The normal and lighting uniforms are declared but unused: there is no lighting calculation here.

### Step 2: Set the fade distance

```glsl
float maxDistance = 10.0;
```

This fixed value is the distance from the world origin at which the fade factor reaches **zero**. Contrary to the source comment, it is not the distance for full opacity. It is measured in the same world units as `vPosition` and is a local constant, not a host-controlled uniform.

### Step 3: Measure distance from the origin

```glsl
float distance = length(vPosition);
```

For `vPosition = (x, y, z)`, this calculates `sqrt(x*x + y*y + z*z)`: the Euclidean distance from `(0, 0, 0)`. For example, `(3, 4, 0)` has distance `5`.

This calculation has no camera-position input. To use actual camera distance, a different shader would need a camera position in the same space and calculate `length(vPosition - cameraPosition)`, or use a suitable view-space position. That change is not present in the current code.

### Step 4: Normalize and clamp the distance

```glsl
float normalizedDistance = clamp(distance / maxDistance, 0.0, 1.0);
```

The division maps distances from 0 to 10 to values from 0 to 1. `clamp` keeps the result within that range; points at or beyond 10 all receive `1.0`. The fixed divisor here is nonzero.

### Step 5: Sample the texture and compute opacity

```glsl
vec4 texColor = texture(u_texture, v_uv);
float opacity = 1.0 - normalizedDistance;
```

`texture` returns RGBA according to the texture and sampler settings. Inverting the normalized distance produces a linear fade factor: 1 at the world origin, 0.5 at distance 5, and 0 at or beyond distance 10.

The fade is radial in world space, not based only on the z axis. For triangles it is evaluated per fragment from the interpolated world position.

### Step 6: Multiply texture alpha by the fade

```glsl
fragColor = vec4(texColor.rgb, texColor.a * opacity);
```

The shader leaves the sampled RGB unchanged and multiplies the sampled alpha by the fade. It does not force alpha to 1 at the origin: the result there is the original texture alpha.

| Distance | Fade factor | Output alpha if texture alpha is 0.8 |
| --- | --- | --- |
| 0 | 1.0 | 0.8 |
| 5 | 0.5 | 0.4 |
| 10 | 0.0 | 0.0 |
| 15 | 0.0 | 0.0 |

The `TODO` comments describe the intended exercise, but the code is already present and uses origin distance rather than camera distance.

## 4. Rendering and troubleshooting

- **Fade is invisible:** alpha output alone does not enable blending. Configure blending in the host to match the texture's alpha representation and choose suitable depth-write and draw-order handling for transparent objects.
- **Object fades in the wrong place:** the center is the world origin. Check the `world` matrix and use a camera-position-based calculation only if camera distance is the intended behavior.
- **Texture coordinates look wrong:** verify the bound texture, UVs, upload orientation, and sampler wrap/filter settings. For points, `v_uv` is per vertex; the shader does not use `gl_PointCoord` for a full point sprite.
- **Point size is missing or unexpected:** this vertex shader does not write `gl_PointSize`; point rendering needs an appropriate vertex shader and a supported point size.
- **Color remains visible when alpha is zero:** with blending disabled, RGB is still written. Zero alpha does not discard the fragment or automatically prevent depth writes.

Compare [particle 5](../particle_5/CODE_EXPLANATION.md), which outputs the texture sample without distance fading.
