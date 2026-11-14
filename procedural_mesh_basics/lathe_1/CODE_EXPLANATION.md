# Lathe 1: Step-by-Step Code Explanation

This example creates a vase-shaped **surface of revolution**: a radius profile is sampled at different heights and rotated around the Y axis. The fragment shader paints horizontal bands and vertical stripes using UV coordinates, then applies simple directional diffuse lighting.

The three source files are:

- [`scene.ts`](./scene.ts): creates indexed positions, UVs, and slope-aware normals.
- [`vert.glsl`](./vert.glsl): transforms vertices using an instance matrix and camera matrices.
- [`frag.glsl`](./frag.glsl): generates the painted pattern and lights it.

The renderer, `ProceduralMeshData` type definition, camera setup, and GPU buffer bindings are not included in this folder.

## 1. Overview of the rendering pipeline

```text
radius profile r(t)
        |
        v
sample 41 horizontal rings, 25 vertices per ring
        |
        v
positions + normals + UVs + triangle indices
        |
        v
renderer uploads vertex/index and instance data
        |
        v
vertex shader: local -> world -> view -> clip
        |
        v
rasterizer interpolates UVs and normals
        |
        v
fragment shader: bands + stripes + diffuse light
        |
        v
opaque output color
```

The lathe produces the vase's curved side surface. It does **not** produce top or bottom caps, an inner wall, or wall thickness.

## 2. Define the vase's radius profile

```ts
function radiusAt(t: number): number {
    return 1.4 + 2.4 * Math.sin(Math.PI * t * 0.9)
         + 0.6 * Math.sin(Math.PI * 3.0 * t);
}
```

The normalized height parameter `t` runs from 0 at the bottom to 1 at the top. The function returns a radius in mesh-local units:

```text
r(t) = 1.4 + 2.4 sin(0.9 pi t) + 0.6 sin(3 pi t)
```

- `1.4` establishes a baseline radius.
- The first sine term gives the broad body its rounded shape.
- The smaller, faster sine term adds variation to the profile.

For example:

| `t` | Interpretation | Approximate radius |
| --- | --- | --- |
| 0 | Bottom ring | 1.4000 |
| 0.5 | Middle-height ring | 3.1705 |
| 1 | Top ring | 2.1416 |

The maximum radius is not necessarily at the middle; these are sample values, not an extrema calculation. This is an analytic profile, not a loaded model or sampled height texture.

## 3. Initialize the mesh and sampling resolution

```ts
const mesh: ProceduralMeshData = {
    vertices: [],
    indices: [],
    normals: [],
    uvs: [],
    colors: []
};

const rows = 40;
const segments = 24;
const height = 11.0;
const startAngle = Math.PI / 4;
```

The mesh begins with empty attribute and index arrays. `rows` specifies the number of vertical intervals; `segments` specifies the number of angular intervals around each ring.

Because the vertex loops include both endpoints:

- There are `rows + 1 = 41` rings.
- Each ring has `segments + 1 = 25` vertices.
- Adjacent angular samples differ by `360 / 24 = 15` degrees.
- Adjacent rings differ in height by `11 / 40 = 0.275` units.

`startAngle` is 45 degrees. It places the UV seam on the radial line where X and Z are both positive and equal. The source comment calls this the front of the vase; its actual screen location depends on the camera and instance transform.

## 4. Sample each horizontal ring

```ts
for (let row = 0; row <= rows; row++) {
    const t = row / rows;
    const y = (t - 0.5) * height;
    const radius = radiusAt(t);
```

For each row:

1. Convert the integer row index into normalized height `t`.
2. Map `t` into a centered vertical coordinate.
3. Evaluate the radius profile at that height.

```text
t = row / 40
y(t) = 11(t - 0.5)
```

The bottom is at `y = -5.5`, the middle at `y = 0`, and the top at `y = 5.5`. All vertices in one ring share the same height and radius.

## 5. Rotate the profile around the Y axis

```ts
for (let segment = 0; segment <= segments; segment++) {
    const u = segment / segments;
    const angle = startAngle + u * Math.PI * 2.0;
    const cos = Math.cos(angle);
    const sin = Math.sin(angle);

    mesh.vertices.push(radius * cos, y, radius * sin);
    mesh.uvs.push(u, t);
```

`u` measures progress around the circumference. Multiplying it by `2 pi` gives a complete turn.

The parametric surface is:

```text
angle(u) = pi/4 + 2 pi u
p(u,t) = (r(t) cos(angle(u)), 11(t - 0.5), r(t) sin(angle(u)))
UV(u,t) = (u,t)
```

For the first bottom vertex, `u = 0`, `t = 0`, and `angle = pi/4`. Its position is approximately `(0.9899, -5.5, 0.9899)` and its UV is `(0,0)`.

### Why the final angular vertex is duplicated

The `segment = 24` vertex completes a full turn and has the same geometric position as `segment = 0`, up to floating-point rounding. Their UVs differ:

```text
first vertex on a ring: position p, UV (0,t)
last vertex on a ring:  position p, UV (1,t)
```

This duplication permits a continuous UV range from 0 to 1 without interpolating directly across the wrap from almost 1 back to 0.

```text
unwrapped surface coordinates

t = 1    +----------------------------------+
         |                                  |
         |              vase side           |
         |                                  |
t = 0    +----------------------------------+
         u = 0                          u = 1
           \                            /
            same geometric seam line
```

The horizontal parameter is angular, not a fixed physical distance: one unit of `u` covers a different circumference wherever the radius changes.

## 6. Derive normals from the profile slope

```ts
const eps = 0.001;
const slope = (radiusAt(t + eps) - radiusAt(t - eps))
            / (2.0 * eps * height);
const length = Math.sqrt(1.0 + slope * slope);
mesh.normals.push(cos / length, -slope / length, sin / length);
```

### Step 1: Approximate the radius derivative

The central-difference formula estimates the derivative with respect to normalized height:

```text
dr/dt approximately [r(t + eps) - r(t - eps)] / (2 eps)
```

The mesh uses physical height `y = height(t - 0.5)`, so `dy/dt = height`. Dividing by `height` converts the derivative into `dr/dy`:

```text
slope = dr/dy approximately [r(t + eps) - r(t - eps)] / (2 eps height)
```

For this profile, the exact derivative provides a useful mathematical comparison:

```text
dr/dt = 2.16 pi cos(0.9 pi t) + 1.8 pi cos(3 pi t)
dr/dy = (dr/dt) / 11
```

The source uses the finite difference, not this analytic expression. At the endpoint rows, it samples slightly outside `[0,1]`; the sine-based function remains defined there and is not clamped.

### Step 2: Construct the outward normal

A purely radial vector `(cos,0,sin)` would be appropriate for a cylinder. The changing vase radius requires the normal to tilt:

```text
n_raw = (cos(angle), -slope, sin(angle))
```

- Positive slope: radius grows upward, so the normal tilts downward.
- Negative slope: radius narrows upward, so the normal tilts upward.
- Zero slope: the normal points horizontally outward.

### Step 3: Normalize the vector

Since `cos(angle)^2 + sin(angle)^2 = 1`, the raw normal's length is `sqrt(1 + slope^2)`. Dividing all three components by that length makes the stored normal unit length.

The profile slope is identical for every vertex on a ring. The current code recomputes it inside the segment loop; this does not change the result.

## 7. Connect neighboring rings with triangles

```ts
const ringSize = segments + 1;
for (let row = 0; row < rows; row++) {
    for (let segment = 0; segment < segments; segment++) {
        const a = row * ringSize + segment;
        const b = a + 1;
        const c = a + ringSize;
        const d = c + 1;
        mesh.indices.push(a, b, c, b, d, c);
    }
}
```

The vertex grid is stored ring by ring. Each cell uses two neighboring vertices on the current ring and two on the next:

```text
                increasing u ->

next ring       c ------------- d
                |           /   |
                |         /     |
                |       /       |
                |     /         |
                |   /           |
current ring    a ------------- b

triangle 1: (a,b,c)
triangle 2: (b,d,c)
shared diagonal: b -- c
```

For the first cell, `ringSize = 25`:

```text
a = 0, b = 1, c = 25, d = 26
indices = (0,1,25), (1,26,25)
```

The final cell on a ring uses the duplicated seam vertex instead of wrapping indices back to the first vertex. The index loops use `< rows` and `< segments`, because there is no further cell beyond the final row or duplicated angular endpoint.

### Important winding/normal distinction

The supplied normals point outward. However, with X and Z defined by `cos(angle)` and `sin(angle)` and angle increasing with `u`, the current `(a,b,c)` ordering has an **inward** geometric orientation. The second triangle uses the same orientation.

For the continuous surface, the cross product of the increasing-angle tangent with the increasing-height tangent is proportional to:

```text
(-cos(angle), slope, -sin(angle))
```

That is opposite to the stored outward normal. Normals affect lighting; triangle winding affects front-face classification and culling. One does not automatically control the other.

With the usual WebGL CCW-front convention and back-face culling, these triangles face the interior. Renderer configuration is not shown, so it cannot be assumed whether that is intentional or whether culling is disabled. Outward winding would reverse each triangle to `(a,c,b)` and `(b,c,d)`; this document explains the code as written and does not change its indices.

## 8. Count the generated geometry

| Quantity | Calculation | Result |
| --- | --- | --- |
| Rings | `40 + 1` | 41 |
| Vertices per ring | `24 + 1` | 25 |
| Vertex entries | `41 * 25` | 1,025 |
| Position numbers | `1,025 * 3` | 3,075 |
| Normal numbers | `1,025 * 3` | 3,075 |
| UV numbers | `1,025 * 2` | 2,050 |
| Surface cells | `40 * 24` | 960 |
| Triangles | `960 * 2` | 1,920 |
| Indices | `1,920 * 3` | 5,760 |
| Color numbers | Not populated | 0 |

`return mesh` passes these arrays to the caller. Unlike the earlier double-sided cube approach, the lathe does not add a reversed copy of every triangle.

## 9. Transform the mesh in `vert.glsl`

### Step 1: Select the shader version and precision

```glsl
#version 300 es
precision highp float;
```

The shader targets GLSL ES 3.00, used by WebGL 2, with high-precision floating-point calculations.

### Step 2: Receive per-vertex attributes

```glsl
in vec3 position;
in vec3 normal;
in vec2 uv;
in vec4 color;
```

Positions, normals, and UVs come from the mesh arrays. `color.r` is used as a material identifier, but the current fragment shader does not use that identifier. The empty `colors` array is therefore not used for the painted colors; the fragment shader generates them mathematically.

Unused inputs/outputs may be optimized away during shader linking. If a future fragment shader uses the material ID, the renderer must supply the corresponding active attribute or a suitable constant attribute value.

### Step 3: Receive per-instance and camera data

```glsl
in vec4 world0;
in vec4 world1;
in vec4 world2;
in vec4 world3;
in float instanceId;
in float instanceSeed;

uniform mat4 view;
uniform mat4 projection;
```

The four `world` vectors form the columns of an instance's world matrix. The renderer must configure them as per-instance attributes. `view` and `projection` define the camera transforms.

### Step 4: Declare outgoing values

```glsl
out vec3 vNormal;
out vec3 vPosition;
out vec2 v_uv;
flat out float vMaterialId;
out float vInstanceId;
out float vInstanceSeed;
```

The current fragment shader consumes `vNormal` and `v_uv`. Other outputs are unused there. `flat` prevents interpolation of the categorical material ID, taking its value from the provoking vertex.

### Step 5: Compute world position and normal

```glsl
mat4 instanceWorld = mat4(world0, world1, world2, world3);
vec4 worldPos = instanceWorld * vec4(position, 1.0);
vPosition = worldPos.xyz;
vNormal = normalize(mat3(instanceWorld) * normal);
```

`w = 1` lets the world matrix translate positions. The upper-left 3x3 portion transforms the normal's direction, and normalization restores unit length. For non-uniform scale or shear, normals generally require the inverse transpose of that 3x3 matrix instead. This matters here because the fragment shader uses normals for lighting.

### Step 6: Forward attributes and compute clip position

```glsl
v_uv = uv;
vMaterialId = color.r;
vInstanceId = instanceId;
vInstanceSeed = instanceSeed;
gl_Position = projection * view * worldPos;
```

The full transform is `p_clip = P * V * M_instance * p_local`, with the rightmost matrix acting first. The GPU then clips and performs perspective division before rasterization. The shader forwards UVs without changing their cylindrical mapping.

## 10. Paint and light the vase in `frag.glsl`

The fragment shader also declares GLSL ES 3.00 and high floating-point precision.

### Step 1: Receive interpolated surface data

```glsl
in vec3 vNormal;
in vec2 v_uv;
out vec4 fragColor;
```

The rasterizer interpolates the vertex normal and UVs over each triangle. The shader has no texture sampler, so the painted pattern does not require an image.

### Step 2: Generate horizontal bands

```glsl
float bands = step(0.5, fract(v_uv.y * 6.0));
```

`v_uv.y` is the normalized height `t`. Multiplication by 6 creates six repeating cycles, `fract` keeps the fractional part in `[0,1)`, and `step` returns 0 below 0.5 and 1 at or above 0.5.

Each cycle has two equal-width color regions, producing six band cycles over the height:

```text
fraction within one cycle:  0 -------- 0.5 -------- 1
bands:                     0           1
```

At exactly `t = 1`, `fract(6)` is zero, so the top boundary returns to the first band state.

### Step 3: Generate vertical stripes

```glsl
float stripes = step(0.5, fract(v_uv.x * 16.0));
```

The same operation creates 16 cycles around the circumference. Because `u` is angular, each cycle spans `360/16 = 22.5` degrees. The pattern returns to the same phase at the duplicated UV seam.

This pattern is evaluated per fragment; it is not limited to the 24 geometric segments per ring.

### Step 4: Choose the band colors

```glsl
vec3 base = mix(
    vec3(0.72, 0.33, 0.18),
    vec3(0.9, 0.78, 0.58),
    bands
);
base = mix(base, base * 0.55, stripes * (1.0 - bands));
```

The first `mix` selects between a reddish-brown and a light cream color. Since `bands` is binary, there is no soft transition.

The second `mix` darkens selected stripe portions only in the brown bands:

| `bands` | `stripes` | Resulting base color |
| --- | --- | --- |
| 0 | 0 | Brown `(0.72,0.33,0.18)` |
| 0 | 1 | Dark brown `(0.396,0.1815,0.099)` |
| 1 | 0 or 1 | Cream `(0.9,0.78,0.58)` |

`stripes * (1 - bands)` disables stripe darkening whenever `bands = 1`.

### Step 5: Normalize the normal and evaluate diffuse lighting

```glsl
vec3 normal = normalize(vNormal);
float diff = max(dot(normal, normalize(vec3(0.5, 0.8, 0.6))), 0.0);
```

Interpolated normals need renormalization. The constant vector supplies a world-space direction toward a light, not a point-light position. Its normalized direction is approximately `(0.4472,0.7155,0.5367)`.

The Lambert-style response is `diff = max(N dot L, 0)`. A normal facing the light receives the largest contribution; a normal facing away receives zero. There is no distance attenuation or shadow calculation.

### Step 6: Write the shaded result

```glsl
fragColor = vec4(base * (0.3 + 0.8 * diff), 1.0);
```

The color multiplier ranges from 0.3 to 1.1 for valid unit directions. The constant 0.3 is a simple ambient-like baseline; `0.8 * diff` adds directional illumination. Alpha is always 1.

The shader does not calculate specular highlights, physically based reflections, tone mapping, or gamma correction. The abrupt `step` patterns may alias when viewed far away; this code does not soften their edges with screen-space derivatives.

## 11. Practical adjustments and checks

- **Shape:** Change `radiusAt` to alter the profile.
- **Smoothness:** Increase `rows` for vertical sampling and `segments` for angular sampling; more samples increase vertex and index counts.
- **Dimensions:** Change `height` for vertical size. Normal slope calculation already divides by that same height.
- **Seam:** Change `startAngle` to move the cylindrical UV seam.
- **Pattern:** Change 6 or 16 to adjust band or stripe repetition.
- **Appearance:** Change the two base colors, 0.55 darkening factor, or light direction.
- **Culling:** Check the renderer's front-face setting against the current inward index winding.
- **Transforms:** Use a proper normal matrix if instances have non-uniform scale.
- **Completeness:** Add separate geometry if you need caps, an inside surface, or wall thickness; none exists in this mesh.

The central idea is to use one normalized parameter for height and another for rotation. Those same parameters generate the geometry and provide UVs for a procedural painted pattern, while the radius derivative supplies normals that follow the curved profile.
