# Particle 5: Displaying a Texture

The [vertex shader](./vert.glsl) transforms geometry and forwards its UV coordinates. The [fragment shader](./frag.glsl) samples a texture at those coordinates and outputs the sampled RGBA value unchanged.

The host application must supply geometry, matrices, a texture, sampler settings, and a draw call. The shaders do not create particles, animate them, or configure blending.

## 1. Overview

1. The host supplies vertices with positions and UV coordinates.
2. The vertex shader transforms positions for rendering and forwards UVs.
3. The GPU rasterizes the primitive and interpolates its varying values.
4. The fragment shader samples `u_texture` using `v_uv`.
5. The sampled red, green, blue, and alpha channels become the fragment output.

## 2. Vertex shader, step by step

### Step 1: Select GLSL version and precision

```glsl
#version 300 es
precision highp float;
```

This is GLSL ES 3.00, used by WebGL 2. `highp` requests high-precision floating-point operations for coordinates and transforms.

### Step 2: Receive the mesh attributes

```glsl
in vec3 position;
in vec3 normal;
in vec2 uv;
```

`position` is the object-space vertex position, `normal` is its object-space normal, and `uv` is its texture coordinate. The host must bind the active attributes from its geometry. Only position and UV affect the current fragment output; the normal is forwarded but not used by the fragment shader.

### Step 3: Receive matrices

```glsl
uniform mat4 world;
uniform mat4 worldView;
uniform mat4 worldViewProjection;
```

`world` transforms object space to world space. `worldViewProjection` transforms object space to clip space, conventionally using projection, view, and world in that order. `worldView` is declared but unused. The host must provide consistent active matrix uniforms.

### Step 4: Declare outputs for the fragment shader

```glsl
out vec3 vNormal;
out vec3 vPosition;
out vec2 v_uv;
```

The fragment shader declares matching inputs. The GPU normally performs perspective-correct interpolation across triangles. Only `v_uv` is read by this fragment shader; unused varyings and associated inputs can be optimized away.

### Step 5: Transform the vertex and forward UVs

```glsl
vec4 worldPos = world * vec4(position, 1.0);
vPosition = worldPos.xyz;
vNormal = normalize(mat3(world) * normal);
v_uv = uv;
gl_Position = worldViewProjection * vec4(position, 1.0);
```

1. Add homogeneous `w = 1` so the world matrix can translate the position.
2. Store the resulting world-space `xyz` in `vPosition`.
3. Transform and normalize the normal.
4. Copy the mesh UV to `v_uv`.
5. Produce clip-space `gl_Position` for clipping and rasterization.

The fragment shader uses the UV but not the world position or normal. The simple normal transform works for rotations and uniform scaling; non-uniform scaling or shear generally requires an inverse-transpose normal matrix.

## 3. Fragment shader, step by step

### Step 1: Receive varyings and uniforms

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

`v_uv` is the coordinate used to sample `u_texture`. The host must bind the intended texture to the sampler's texture unit. The other varyings and lighting uniforms are declared but unused: this shader applies no light, tint, or shininess.

### Step 2: Sample the texture

```glsl
vec4 texColor = texture(u_texture, v_uv);
```

`texture` returns the sampled RGBA value. UVs commonly range from 0 to 1 across a texture, but behavior outside that range depends on sampler wrapping. Filtering, mipmaps, and the bound texture's format also affect the sampled value.

For a triangle, `v_uv` varies across the surface based on its vertices. For a point primitive, `v_uv` comes from the point's vertex; this shader does **not** use `gl_PointCoord` to map the whole texture across the point sprite.

### Step 3: Write the sample unchanged

```glsl
fragColor = texColor;
```

The output preserves the sampled RGBA values as the fragment shader output. For example, a sample `(0.2, 0.6, 0.9, 0.5)` is written as `(0.2, 0.6, 0.9, 0.5)`. The source's `TODO` is an exercise prompt; the sample and output are already implemented.

Writing alpha does not by itself enable transparency. Whether the fragment blends with the background depends on the host's blend state, attachment, and depth settings. The destination format or later rendering steps can also affect the displayed result.

## 4. Practical checks

- **Incorrect texture:** verify the texture binding, sampler uniform, and texture unit.
- **Unexpected orientation or repetition:** check the mesh UVs, uploaded texture orientation, and sampler wrap mode.
- **Alpha does not look transparent:** configure blending in the host and choose depth handling appropriate for transparent objects.
- **A point has only one sampled color:** this shader samples the per-vertex `v_uv`, not `gl_PointCoord`. It also does not assign `gl_PointSize`; a point-rendering setup needs a vertex shader that writes an appropriate size.

[Particle 6](../particle_6/CODE_EXPLANATION.md) builds on the same texture sampling pattern by multiplying its alpha by a distance-based fade.
