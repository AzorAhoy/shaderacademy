# Step-by-Step Explanation of the Procedural Mesh 7 Code

This folder contains three parts of a simple textured procedural-mesh example:

- [`scene.ts`](./scene.ts) builds indexed geometry for a cube from six reusable quads.
- [`vert.glsl`](./vert.glsl) transforms mesh vertices using per-instance and camera transforms, then forwards attributes to the fragment stage.
- [`frag.glsl`](./frag.glsl) samples a 2D texture using the interpolated UV coordinate.

The shader inputs and uniforms must be connected by the renderer. The TypeScript file builds mesh arrays, but does not show the renderer, texture loading, or GPU buffer-binding code.

## 1. Building a quad in `scene.ts`

### Step 1: Declare the reusable quad helper

```ts
function createQuad(
    corners: number[],
    normal: [number, number, number],
    doubleSided = true
) {
```

`createQuad` creates one rectangular face from four 3D corner positions. `corners` is a flat array containing four `(x, y, z)` points, `normal` is the direction shared by that face, and `doubleSided` controls whether triangles are added for both winding directions. It defaults to `true`.

The function returns arrays of vertex positions, triangle indices, normals, and UV coordinates. It does not create GPU buffers itself.

### Step 2: Copy the positions and define the front-facing triangles

```ts
const vertices = [...corners];
const indices: number[] = [0, 1, 2, 0, 2, 3];
```

The corners are copied so the returned vertex array is separate from the input array. The six indices describe two triangles that form a quad:

- Triangle one uses vertices `0, 1, 2`.
- Triangle two uses vertices `0, 2, 3`.

The triangles share the diagonal from corner 0 to corner 2. This is indexed geometry: indices refer to entries in the quad's vertex arrays rather than duplicating positions for every triangle.

### Step 3: Assign the face normal to each corner

```ts
const normals: number[] = [
    normal[0], normal[1], normal[2],
    normal[0], normal[1], normal[2],
    normal[0], normal[1], normal[2],
    normal[0], normal[1], normal[2]
];
```

There are four vertices, so the same three-component face normal is repeated four times. Each vertex receives one normal. Repeating face vertices between quads lets each cube face have its own normal, which is useful for crisp, flat-shaded sides.

### Step 4: Assign UV coordinates to the four corners

```ts
const uvs: number[] = [
    0, 0,
    1, 0,
    1, 1,
    0, 1,
];
```

Each vertex receives a two-component texture coordinate. The four corners cover the square UV range from `(0, 0)` to `(1, 1)`, so the full texture maps across each face. How those coordinates appear visually also depends on texture orientation and wrapping configured by the renderer.

The source has a TODO comment about adding UVs for each quad. Currently, this helper uses the same UV pattern for every face.

### Step 5: Optionally add reverse-winding triangles

```ts
if (doubleSided) {
    indices.push(0, 2, 1, 0, 3, 2);
}
```

These are the same two triangles with their vertex order reversed. Triangle winding determines which side is considered the front face when face culling is enabled. Adding both windings makes triangles available from either side under ordinary back-face culling.

This does not create new vertices or reverse the normals; it only adds more indices. With the default `true`, one quad has 12 indices total, representing four triangles (two for each winding direction).

### Step 6: Return the quad data

```ts
return { vertices, indices, normals, uvs };
```

The helper returns the four arrays needed to append this quad to the larger mesh.

## 2. Appending a quad to the mesh

### Step 1: Find the first new vertex's offset

```ts
const vertexOffset = target.vertices.length / 3;
```

Positions are stored as three numbers per vertex. Dividing the current position-array length by three gives the number of vertices already in the target mesh. This count becomes the offset for the new quad's indices.

### Step 2: Append the vertex attributes

```ts
target.vertices.push(...quad.vertices);
target.normals.push(...quad.normals);
target.uvs.push(...quad.uvs);
```

The new quad's positions, normals, and UVs are added to the matching arrays in the target mesh. The `...` spread syntax passes each array element as an individual argument to `push`.

### Step 3: Offset and append the indices

```ts
quad.indices.forEach((index) => target.indices.push(index + vertexOffset));
```

Each index in a quad is relative to that quad, where its vertices are numbered 0 through 3. Adding `vertexOffset` changes it to an index into the combined mesh. Without the offset, later quads would incorrectly refer to the first quad's vertices.

## 3. Constructing the cube

### Step 1: Initialize the mesh data

```ts
const mesh: ProceduralMeshData = {
    vertices: [],
    indices: [],
    normals: [],
    uvs: [],
    colors: []
};
```

The mesh starts with empty arrays for positions, indices, normals, UVs, and colors. `ProceduralMeshData` is assumed to be defined elsewhere; its definition is not included in this folder.

The `colors` array remains empty in this function. That is worth noting because the vertex shader declares a `color` input. The renderer must provide a suitable color attribute/default, or the mesh setup must be extended to populate colors for that shader input.

### Step 2: Choose the cube's half-size

```ts
const halfSize = 2.0;
```

The cube's coordinates extend from `-2.0` to `2.0` on each axis. Therefore, its side length is `4.0`, and it is centered at the origin.

### Step 3: Create and append the six faces

Each `appendQuad(mesh, createQuad([...], normal))` call describes one cube face. The four listed points are that face's corners, and the normal identifies its outward direction:

1. **Positive Z face:** corners lie at `z = +halfSize`; normal is `(0, 0, 1)`.
2. **Negative Z face:** corners lie at `z = -halfSize`; normal is `(0, 0, -1)`.
3. **Positive X face:** corners lie at `x = +halfSize`; normal is `(1, 0, 0)`.
4. **Negative X face:** corners lie at `x = -halfSize`; normal is `(-1, 0, 0)`.
5. **Positive Y face:** corners lie at `y = +halfSize`; normal is `(0, 1, 0)`.
6. **Negative Y face:** corners lie at `y = -halfSize`; normal is `(0, -1, 0)`.

Each face has its own four vertices, so the completed cube has 24 vertex entries rather than sharing the eight geometric corner positions. This duplication allows each face to use a distinct normal and its own complete UV square.

Because `doubleSided` defaults to `true`, each face contributes 12 indices. Six faces therefore contribute 72 indices, or 24 indexed triangles.

### Step 4: Return the completed mesh

```ts
return mesh;
```

The caller receives the mesh arrays. This function only builds the data; another part of the application must upload and draw it.

## 4. Transforming vertices in `vert.glsl`

### Step 1: Select GLSL ES and precision

```glsl
#version 300 es
precision highp float;
```

This selects GLSL ES 3.00, commonly used with WebGL 2, and requests high-precision floating-point calculations.

### Step 2: Declare mesh attributes

```glsl
in vec3 position;
in vec3 normal;
in vec2 uv;
in vec4 color;
```

These are per-vertex inputs supplied by mesh buffers:

- `position`: local-space vertex position.
- `normal`: local-space vertex normal.
- `uv`: texture coordinate.
- `color`: per-vertex color; this shader uses its red component as a material identifier.

As noted above, `scene.ts` does not fill the `colors` array. The rendering setup must account for that input.

### Step 3: Declare the per-instance transform and identifiers

```glsl
in vec4 world0;
in vec4 world1;
in vec4 world2;
in vec4 world3;

in float instanceId;
in float instanceSeed;
```

The four `world` inputs are the four columns of an instance's transformation matrix. The renderer must bind these per-instance attributes and configure their divisors so each instance receives its own matrix. The shader assembles the columns into a `mat4` in the next step.

`instanceId` and `instanceSeed` are additional per-instance values. This vertex shader forwards them, but the current fragment shader does not use them.

### Step 4: Declare camera transforms

```glsl
uniform mat4 view;
uniform mat4 projection;
```

These uniforms provide the camera's view transform and projection transform. The renderer supplies them for the current camera.

### Step 5: Declare values passed to the fragment shader

```glsl
out vec3 vNormal;
out vec3 vPosition;
out vec2 v_uv;
flat out float vMaterialId;
out float vInstanceId;
out float vInstanceSeed;
```

The `out` values are sent to the rasterizer and interpolated across primitives before becoming inputs to a fragment shader. `flat` on `vMaterialId` disables interpolation: each fragment receives one provoking-vertex value rather than a blend. This is appropriate for a material ID, which is categorical rather than a smoothly varying quantity.

The current fragment shader only declares and uses `v_uv`. The other outputs are available for other material or shading logic but are unused by this fragment shader.

### Step 6: Build the instance matrix and transform the position

```glsl
mat4 instanceWorld = mat4(world0, world1, world2, world3);
vec4 worldPos = instanceWorld * vec4(position, 1.0);
vPosition = worldPos.xyz;
```

The four input vectors are assembled as the columns of a matrix. The local position is made homogeneous by adding `w = 1`, then transformed into world space. Its `xyz` components are passed on as `vPosition`.

### Step 7: Transform the normal

```glsl
vNormal = normalize(mat3(instanceWorld) * normal);
```

The instance matrix's upper-left 3×3 portion transforms the normal direction, then `normalize` makes it unit length. This is suitable for rotations and uniform scales. For non-uniform scaling or shear, a normal matrix based on the inverse transpose is generally needed to preserve correct perpendicular directions. The current fragment shader does not use `vNormal`.

### Step 8: Forward UVs and per-instance data

```glsl
v_uv = uv;
vMaterialId = color.r;
vInstanceId = instanceId;
vInstanceSeed = instanceSeed;
```

UVs pass unchanged to the fragment shader for texture sampling. The red channel of vertex color is copied as a flat material ID. The instance ID and seed are also forwarded, but none of these additional values affects the current texture-only fragment shader.

### Step 9: Transform to clip space

```glsl
gl_Position = projection * view * worldPos;
```

The world-space position is transformed by the camera view matrix and then the projection matrix. `gl_Position` is the required clip-space output used by the graphics pipeline to clip, rasterize, and place the vertex on screen.

## 5. Sampling the texture in `frag.glsl`

### Step 1: Declare the fragment input and output

```glsl
in vec2 v_uv;
out vec4 fragColor;
```

`v_uv` is the interpolated texture coordinate for the current fragment. `fragColor` is the RGBA color written for that fragment. The input name and type match the `v_uv` output in `vert.glsl`.

### Step 2: Declare the 2D texture

```glsl
uniform sampler2D u_texture;
```

`u_texture` is a handle to a 2D texture bound by the application. The renderer must bind the intended texture and assign its texture unit to this sampler uniform.

### Step 3: Sample and output the texture

```glsl
fragColor = texture(u_texture, v_uv);
```

`texture` looks up the texture at the current interpolated UV coordinate and returns its RGBA value. That value is written directly to the screen/render target. No lighting, tint, material-ID selection, or other color calculation is performed in this fragment shader.

## 6. End-to-end data flow

1. `createMesh` calls `createQuad` six times to describe the cube's faces.
2. Each quad supplies four positions, a repeated face normal, UVs, and triangle indices.
3. `appendQuad` adds those arrays to the combined mesh and offsets the indices so they address the correct vertices.
4. The renderer uploads the resulting mesh data and supplies the instance matrix, camera matrices, texture, and any required extra attributes.
5. `vert.glsl` transforms each vertex through instance, view, and projection space, and forwards its UV coordinate.
6. The rasterizer interpolates UVs across the triangles.
7. `frag.glsl` samples `u_texture` at each fragment's UV and writes the sampled RGBA color.

The folder does not include the renderer or texture setup, so attribute bindings, instance configuration, texture selection, and buffer upload are external to these three files.
