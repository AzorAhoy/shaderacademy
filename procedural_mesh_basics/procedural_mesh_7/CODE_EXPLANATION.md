# Step-by-Step Explanation of the Procedural Mesh 7 Code

This folder contains three parts of a simple textured procedural-mesh example:

- [`scene.ts`](./scene.ts) builds indexed geometry for a cube from six reusable quads.
- [`vert.glsl`](./vert.glsl) transforms mesh vertices using per-instance and camera transforms, then forwards attributes to the fragment stage.
- [`frag.glsl`](./frag.glsl) samples a 2D texture using the interpolated UV coordinate.

The shader inputs and uniforms must be connected by the renderer. The TypeScript file builds mesh arrays, but does not show the renderer, texture loading, or GPU buffer-binding code.

### Reading order

1. Start with `createQuad`: learn how one face stores its positions, normals, indices, and UVs.
2. Read `appendQuad`: see how independent faces become one indexed mesh.
3. Read `createMesh`: identify the six faces of the cube.
4. Follow `vert.glsl`: track each vertex from local space to clip space.
5. Finish with `frag.glsl`: see how interpolated UVs select the displayed texture color.

```text
scene.ts                Renderer                 GPU
quad arrays ---------> vertex/index buffers ---> vert.glsl
instance matrices ---> per-instance attributes       |
camera matrices -----> uniforms                      v
                                               rasterization
texture -------------> sampler binding               |
                                                     v
                                                frag.glsl
                                                     |
                                                     v
                                                output color
```

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

The TypeScript tuple `[number, number, number]` requires three normal components at type-check time. In contrast, `number[]` does not enforce a particular length. The helper assumes `corners` contains exactly 12 numbers in perimeter order, describing four nondegenerate, coplanar points; it does not validate that assumption at runtime.

### Step 2: Copy the positions and define the front-facing triangles

```ts
const vertices = [...corners];
const indices: number[] = [0, 1, 2, 0, 2, 3];
```

The corners are copied so the returned vertex array is separate from the input array. The six indices describe two triangles that form a quad:

- Triangle one uses vertices `0, 1, 2`.
- Triangle two uses vertices `0, 2, 3`.

The triangles share the diagonal from corner 0 to corner 2. This is indexed geometry: indices refer to entries in the quad's vertex arrays rather than duplicating positions for every triangle.

For the first face, viewed from its outward `+Z` side, the positions and UVs line up as follows:

```text
  +Y
  ^
  |
  3 ---------------- 2
  |                / |
  |              /   |
  |            /     |
  |          /       |
  |        /         |
  |      /           |
  |    /             |
  |  /               |
  0 ---------------- 1 ----> +X

triangle A: 0 -> 1 -> 2
triangle B: 0 -> 2 -> 3
shared diagonal: 0 -- 2
```

The vertex index is not an offset into the raw number array. Index `2` means the third vertex, whose position occupies entries `6`, `7`, and `8`:

```text
position of vertex i = (vertices[3*i], vertices[3*i+1], vertices[3*i+2])
UV of vertex i       = (uvs[2*i], uvs[2*i+1])
```

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

| Vertex | Position on the pictured face | UV |
| --- | --- | --- |
| 0 | Lower-left | `(0, 0)` |
| 1 | Lower-right | `(1, 0)` |
| 2 | Upper-right | `(1, 1)` |
| 3 | Upper-left | `(0, 1)` |

These corner labels apply to the pictured positive-Z face. Other faces have different local orientations. Each face covers the whole texture independently; the six faces are not laid out as a single cube texture atlas.

### Step 5: Optionally add reverse-winding triangles

```ts
if (doubleSided) {
    indices.push(0, 2, 1, 0, 3, 2);
}
```

These are the same two triangles with their vertex order reversed. Triangle winding determines which side is considered the front face when face culling is enabled. Adding both windings makes triangles available from either side under ordinary back-face culling.

This does not create new vertices or reverse the normals; it only adds more indices. With the default `true`, one quad has 12 indices total, representing four triangles (two for each winding direction).

The two index sets are:

```text
outward winding:  (0, 1, 2), (0, 2, 3)
reversed winding: (0, 2, 1), (0, 3, 2)
```

For the positive-Z face, the first triangle's edges are `(4, 0, 0)` and `(4, 4, 0)`. Their cross product is `(0, 0, 16)`, pointing outward along `+Z`. Swapping their order reverses that direction.

This winding-derived orientation controls face classification; the separately supplied `normal` attribute controls shading. Reversed indices do not automatically make that attribute point inward. With culling disabled, both copies are submitted, which may produce unnecessary work or blending artifacts depending on depth and blend settings.

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

**Worked example:** After appending the first face, `target.vertices.length` is 12. The second face therefore starts at vertex `12 / 3 = 4`:

```text
second face's local indices:  0, 1, 2, 0, 2, 3
add vertexOffset = 4:         4, 5, 6, 4, 6, 7

first face uses vertices:    0..3
second face uses vertices:   4..7
third face uses vertices:    8..11
```

The offset is measured in vertices, not triangles or position-array elements. This is why the function divides the position-array length by three before offsetting indices.

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

The `colors` array remains empty in this function. The vertex shader declares a `color` input, but its derived material-ID output is not consumed by the current fragment shader. A shader compiler may therefore optimize this input away. If a different fragment shader uses that ID, the renderer must provide the active color attribute or a suitable constant attribute value.

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

### Resulting array sizes

| Array | Numbers per vertex/face | Completed cube |
| --- | --- | --- |
| `vertices` | 3 per vertex | `24 * 3 = 72` numbers |
| `normals` | 3 per vertex | `24 * 3 = 72` numbers |
| `uvs` | 2 per vertex | `24 * 2 = 48` numbers |
| `indices` | 12 per double-sided face | `6 * 12 = 72` indices |
| `colors` | Not populated | 0 numbers |

There are 12 distinct geometric triangles covering the cube surface, submitted in both winding directions for 24 indexed triangles. If all faces were created with `doubleSided = false`, the position, normal, and UV arrays would stay the same, but there would be 36 indices and 12 submitted triangles.

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

As noted above, `scene.ts` does not fill the `colors` array. The rendering setup must account for that input if it remains active in the linked shader program.

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

**Formula:**

```text
p_world = M_instance * (x_local, y_local, z_local, 1)
```

For example, a translation-only instance matrix moving the cube by `(3, 0, 0)` sends the local corner `(2, -2, 2)` to world position `(5, -2, 2)`. A different instance can use the same mesh arrays with a different transform.

### Step 7: Transform the normal

```glsl
vNormal = normalize(mat3(instanceWorld) * normal);
```

The instance matrix's upper-left 3x3 portion transforms the normal direction, then `normalize` makes it unit length. This is suitable for rotations and uniform scales. For non-uniform scaling or shear, a normal matrix based on the inverse transpose is generally needed to preserve correct perpendicular directions. The current fragment shader does not use `vNormal`.

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

**Full transform chain:**

```text
p_clip = P * V * M_instance * p_local
p_ndc  = p_clip.xyz / p_clip.w
```

The rightmost matrix acts first. The GPU performs clipping and the perspective divide after the vertex shader; this shader should output `p_clip`, not manually divide it before assigning `gl_Position`.

## 5. Sampling the texture in `frag.glsl`

Like the vertex shader, this file begins with `#version 300 es` and `precision highp float`. It targets GLSL ES 3.00 and sets the default floating-point precision for its calculations.

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

### How interpolation fills the face

The mesh only assigns UVs at the four corners, but the rasterizer supplies UVs for every fragment inside each triangle. Under perspective projection, the default interpolation is perspective-correct:

```text
uv_fragment = sum(lambda_i * uv_i / w_i) / sum(lambda_i / w_i)
```

Here `lambda_i` are screen-space barycentric weights for the triangle's three vertices, and `w_i` are their clip-space `w` values. If all three `w_i` are equal, the formula becomes an ordinary weighted average. For a face viewed straight on with equal `w`, its center maps to approximately `(0.5, 0.5)`, the texture's center.

The sampled alpha is preserved by `fragColor`. Whether it produces transparency depends on the renderer's blending setup; returning an alpha value alone does not enable blending.

## 6. End-to-end data flow

1. `createMesh` calls `createQuad` six times to describe the cube's faces.
2. Each quad supplies four positions, a repeated face normal, UVs, and triangle indices.
3. `appendQuad` adds those arrays to the combined mesh and offsets the indices so they address the correct vertices.
4. The renderer uploads the resulting mesh data and supplies the instance matrix, camera matrices, texture, and any required extra attributes.
5. `vert.glsl` transforms each vertex through instance, view, and projection space, and forwards its UV coordinate.
6. The rasterizer interpolates UVs across the triangles.
7. `frag.glsl` samples `u_texture` at each fragment's UV and writes the sampled RGBA color.

The folder does not include the renderer or texture setup, so attribute bindings, instance configuration, texture selection, and buffer upload are external to these three files.

## 7. Practical setup and troubleshooting checklist

1. **Geometry:** Supply four valid corners per quad and keep positions, normals, and UVs aligned by vertex index.
2. **Indices:** Apply the existing vertex offset whenever another face is appended.
3. **Instancing:** Bind all four world-matrix columns in GLSL column order and set their attribute divisors for per-instance data.
4. **Camera:** Supply compatible view and projection matrices.
5. **Texture:** Load and bind the texture, assign its texture unit to `u_texture`, and configure the desired filtering and wrapping.
6. **Faces:** Check front-face/culling settings if faces disappear when viewed from one side.
7. **Appearance:** The current material is texture-only. Changing normals or adding lights will not change its color until the fragment shader performs lighting.
8. **Extra attributes:** Normal, position, material ID, and instance identifiers forwarded by the vertex shader are unused by this fragment shader and may be optimized away.

The TypeScript code's role is data construction, the vertex shader's role is transformation and attribute forwarding, and the fragment shader's role is texture lookup. Keeping these responsibilities separate makes it easier to determine which stage to inspect when the rendered cube looks incorrect.
