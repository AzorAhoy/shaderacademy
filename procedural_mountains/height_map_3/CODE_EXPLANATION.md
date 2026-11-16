# Height Map 3: Making a Pyramid, Step by Step

Imagine a square sheet made of triangles. We want to pull its middle into a
point, then shine a light on it. Two small GPU programs work together:

1. The [vertex shader](./vert.glsl) moves the sheet's points to make the shape.
2. The [fragment shader](./frag.glsl) decides the color of each visible piece
   of the shape, based on a light.

The shader works out how far to move a point using its UV coordinates. It
does not read a height-map image.

The renderer must supply the mesh, its attributes, the transformation matrices,
and the lighting uniforms. No scene or mesh-generation code is included in this
folder, so the exact mesh dimensions, UV layout, camera, and appearance cannot
be determined from the shaders alone.

### A few words to know

- **Vertex:** a point in a 3D mesh. The plural is vertices.
- **Triangle:** a flat surface joining three vertices. A mesh is made of
  triangles.
- **UV:** two numbers that say where a vertex sits on a 2D coordinate map.
  Think of them as a label on the sheet: `u` goes across and `v` goes up the
  map. The center of a `[0, 1]` map is `(0.5, 0.5)`.
- **Normal:** an arrow that tells the lighting code which way a surface
  points.
- **Local space:** the object's own coordinate system. **World space** is
  the shared coordinate system used to place the object and light.
- **Shader:** a small program that runs on the GPU. The vertex shader works
  on vertices; the fragment shader works on fragments, which can contribute
  to the final pixels.

## What shape does the code make?

The center moves the most: `4` units along **negative local Z**. The edges
do not move. In between, points move by smaller amounts.

Picture a flat square in the object's local XY plane, with UVs spread evenly
across it. If the mesh has a center vertex and triangles aligned with the
four sides, pulling that center in negative local Z forms a square pyramid.
This is the shape before the host's world transform, which can also stretch
or shear it.

The shader does not require the input to be an XY square. A different plane
orientation, non-square or distorted UV mapping, existing Z values, or
insufficient mesh subdivisions can produce a different result.

Negative local Z is a direction in the mesh's coordinate system, not
automatically down in the world. The `world` matrix determines how that
direction is oriented. The vertex shader's comment calls negative Z "up":
that describes the lesson's intended local up direction, not a universal
world-space rule. For example, if `world` rotates local `-Z` to world
`+Y`, the apex points upward. If the original local XY plane is horizontal
and local `-Z` points downward, its center instead moves below its boundary.
The shader alone does not specify which orientation the host uses.

```text
UV view

(0,1) +-------------+ (1,1)
      | \         / |
      |   \     /   |
      |     \ /     |
      |      *      | center
      |     / \     |
      |   /     \   |
      | /         \ |
(0,0) +-------------+ (1,0)

Cross-section through v = 0.5: displacement along local -Z

4 |       *
  |      / \
  |     /   \
  |    /     \
  |   /       \
0 |  *---------*
     0   0.5   1  u
```

The drawings represent the ideal function over a square UV domain, not a
guarantee about the submitted mesh. The cross-section plots displacement
along local `-Z` upward on the page; it does not assert that `-Z` is world
up. The lines in the UV view separate the four linear regions; they are not
necessarily mesh edges.

### A concrete local-space example

Suppose a flat square is centered at `(0, 0, 0)`, and its corners have the
four corner UVs. Its center vertex has UV `(0.5, 0.5)`. The shader leaves
the corners alone and moves the center to `(0, 0, -4)`. Four triangles
joining the center to the corners form the four sides of a pyramid. This is
an example mesh, not one provided by the lesson.

## Pipeline overview

1. The host supplies each vertex's local `position`, local `normal`, and `uv`.
2. The vertex shader computes a height from `uv` and adds it to local Z.
3. It transforms the displaced position to world space for lighting and to
   clip space for rasterization.
4. It forwards a transformed normal and the UV to the fragment shader.
5. Rasterization interpolates the outputs across each triangle.
6. The fragment shader calculates diffuse light and writes a color with
   alpha `1`.

## Vertex shader, step by step

### 1. Declare the shader interface

```glsl
#version 300 es
precision highp float;

in vec3 position;
in vec3 normal;
in vec2 uv;

uniform mat4 world;
uniform mat4 worldView;
uniform mat4 worldViewProjection;

out vec3 vNormal;
out vec3 vPosition;
out vec2 v_uv;
```

The first two lines tell the GPU which shader language version to use and
request high precision for decimal numbers.

Think of the remaining declarations as labels on boxes:

- `in` boxes receive information for each vertex: `position`, `normal`,
  and `uv`.
- `uniform` boxes receive values from the host, such as the transformation
  matrices. They are shared across the draw rather than supplied separately
  for each vertex.
- `out` boxes carry information to the next stage.

`vec2` holds two numbers, `vec3` holds three, and `mat4` is a 4-by-4
matrix: a set of numbers used here to transform positions.

`world` transforms local positions into world space.
`worldViewProjection` transforms local positions into clip space for the
camera. For the lighting and rendered positions to agree, the host must
provide compatible transforms: for the usual column-vector convention,
`worldViewProjection = projection * view * world`. The code uses
`worldPos.xyz` without dividing by `w`, so it assumes an affine `world`
transform. `worldView` is declared but not used; a compiler may optimize it
away. The vertex outputs used by the fragment shader are interpolated across
triangles. Although `v_uv` is passed through, the fragment shader does not
actually use it, so it may be optimized away.

### 2. Copy the position and choose the displacement scale

```glsl
vec3 modifiedPosition = position;
float pyramidHeight = 4.0;
```

The first line makes a copy of the point's location. The shader changes the
copy, leaving the input `position` unchanged.

`pyramidHeight` is the maximum movement in local units for the usual UV
square. It is set to `4.0` directly in the shader. The actual center offset
will be `-4.0`, because the calculated height there is `-1`.

### 3. Measure distance from the UV center

```glsl
vec2 distFromCenter = abs(uv - 0.5);
```

The shader wants to know how far the point's label is from the middle.
First it subtracts `(0.5, 0.5)` from the UV. Then `abs` removes minus signs:
for example, both `-0.25` and `0.25` become `0.25`.

Here is the calculation for three labels:

| `uv` | `uv - 0.5` | `distFromCenter` |
| --- | --- | --- |
| `(0.5, 0.5)` | `(0, 0)` | `(0, 0)` |
| `(0.25, 0.5)` | `(-0.25, 0)` | `(0.25, 0)` |
| `(1, 0)` | `(0.5, -0.5)` | `(0.5, 0.5)` |

The two results tell us the distance across and the distance up the UV map.
They are not yet one combined distance.

### 4. Turn those distances into a square height profile

```glsl
float height = -1.0 + max(distFromCenter.x, distFromCenter.y) * 2.0;
```

Read this line in three small steps:

1. `max(...)` chooses the bigger of the two distances. For `(0.25, 0)`,
   it chooses `0.25`.
2. Multiply that number by `2`: `0.25 * 2 = 0.5`.
3. Add `-1`: `-1 + 0.5 = -0.5`. This is the `height` for that UV.

The bigger-distance rule is called **Chebyshev distance**. You do not need
to memorize the name: the important part is that the shader chooses the
larger of the two distances.

The `max` operation makes equal-height contours square in **UV space**
rather than circular. For example, both `(0.75, 0.5)` and `(0.75, 0.75)`
have Chebyshev distance `0.25`, so both get `height = -0.5`. Their
Euclidean distances from the center are different: `0.25` and approximately
`0.354`, respectively. Using Euclidean distance instead would produce a
different, circular profile.

In the square-pyramid example, the bigger component decides which of the
four sides a point belongs to. Where the two distances are equal, the sides
meet along a crease. The actual shape also depends on the mesh's UV mapping
and transforms.

| UV | Maximum distance | `height` | Z displacement (`height * 4`) |
| --- | --- | --- | --- |
| `(0.5, 0.5)` | `0` | `-1` | `-4` |
| `(0.25, 0.5)` | `0.25` | `-0.5` | `-2` |
| `(0, 0.5)` | `0.5` | `0` | `0` |
| `(1, 1)` | `0.5` | `0` | `0` |

For UVs outside the `[0, 1]` square, the shader does not clamp the result:
the maximum distance exceeds `0.5`, making the displacement positive.

### 5. Displace the vertex

```glsl
modifiedPosition.z += height * pyramidHeight;
```

The shader multiplies `height` by `pyramidHeight`, then **adds** the result
to the point's original Z. It does not replace Z, and it does not change X
or Y.

Follow one point all the way through:

1. Start with position `(2, 1, 0.5)` and UV `(0.25, 0.5)`.
2. As shown above, that UV gives `height = -0.5`.
3. Multiply by `pyramidHeight`: `-0.5 * 4 = -2`.
4. Add the offset to Z: `0.5 + (-2) = -1.5`.
5. Keep X and Y, giving the new position `(2, 1, -1.5)`.

The shader has a `TODO` comment above this code, but the following lines
already implement the displacement. Changing `pyramidHeight` to `0` removes
it. A negative value reverses the displacement direction and can produce an
apex along local `+Z` on the same flat plane. Whether either direction is
upward in the world depends on the world transform. Both values are still
measured in local units before the world transform.

### 6. Send the displaced position to lighting and the camera

```glsl
vec4 worldPos = world * vec4(modifiedPosition, 1.0);

vPosition = worldPos.xyz;
vNormal = normalize(mat3(world) * normal);
v_uv = uv;

gl_Position = worldViewProjection * vec4(modifiedPosition, 1.0);
```

Think of the matrices as instructions for placing and viewing the point.
`vec4(modifiedPosition, 1.0)` adds a fourth number, `1`, so a position
transform can also move the point.

- `world * ...` places the moved point in the shared world. The lighting
  code uses this position.
- `vNormal` carries the transformed normal arrow for lighting.
- `v_uv` carries the UV, although this fragment shader does not use it.
- `worldViewProjection * ...` prepares the **same moved point** for the
  camera. The GPU uses `gl_Position` to draw the triangles.

`mat3(world)` extracts the linear part of `world` and transforms the
original normal without applying translation. The vertex shader normalizes
the result, and forwards the unchanged UV. See the limitations below: this
normal calculation does not account for the displacement and is not
generally correct under non-uniform world scaling.

## Fragment shader, step by step

### 1. Receive interpolated values and lighting inputs

```glsl
in vec3 vNormal;
in vec3 vPosition;
in vec2 v_uv;

uniform vec3 lightPosition;
uniform vec3 lightColor;
uniform vec3 objectColor;

out vec4 fragColor;
```

The fragment shader receives interpolated world-space positions and normals.
`lightPosition` must also be in world space so the subtraction below is
meaningful. `lightColor` and `objectColor` control the light and material
colors. The UV input is declared but not used in the fragment calculation.

### 2. Calculate the direction to the light

```glsl
vec3 normal = normalize(vNormal);
vec3 lightDir = normalize(lightPosition - vPosition);
```

The normal is an arrow pointing away from the surface. The GPU blends the
arrows between vertices, so `normalize` makes this arrow one unit long again.

`lightPosition - vPosition` is another arrow: it points from the surface
toward the light. The second `normalize` keeps its direction but makes its
length one too. A zero-length normal, or a light exactly at the fragment
position, cannot be normalized reliably.

### 3. Calculate Lambert diffuse lighting

```glsl
float diff = max(dot(normal, lightDir), 0.0);
vec3 diffuse = diff * lightColor;
```

The dot product compares the two arrows. Because they have length one:

- A result of `1` means they point the same way: the light hits directly.
- A result of `0` means they point at right angles: there is no diffuse light.
- A negative result means the normal points away from the light. `max`
  changes that result to `0`, so the light amount never goes below zero.

Finally, `diff * lightColor` makes the light color weaker or stronger.

For example, a normal `(0, 0, 1)` and normalized light direction
`(0, 0.6, 0.8)` have dot product `0.8`. With light color `(1, 1, 1)`,
`diffuse` is `(0.8, 0.8, 0.8)`.

### 4. Apply the object color and output alpha

```glsl
vec3 result = diffuse * objectColor;
fragColor = vec4(result, 1.0);
```

GLSL multiplies the RGB vectors component by component. With the example
diffuse value above and object color `(0.5, 0.25, 1)`, the result is
`(0.4, 0.2, 0.8)`. The shader outputs alpha `1`; the final pixel also
depends on the renderer's blending and output settings.

This is diffuse lighting only: there is no ambient term, specular highlight,
shadow test, or distance attenuation. A surface facing away from the light
can therefore be black. Final color handling also depends on the renderer
and output target.

## Mesh and lighting limitations

### Vertex density and UV layout

The height is evaluated **only at vertices**, not at every fragment.
Triangles connect the displaced vertices with straight edges. Consider a
flat quad with only four vertices, each assigned a corner UV such as
`(0, 0)` or `(1, 1)`. These UVs are on the boundary, where displacement
is zero, so the quad remains flat even though the mathematical height
function has its greatest displacement in the middle.

For the square-pyramid example above, use a local XY square with the stated
UV mapping and a vertex at the center. To reproduce the ideal pyramid
exactly, the mesh triangles must also align with its four linear regions
and their creases. A generic grid may only approximate the profile; a denser
mesh alone does not guarantee exact alignment. Existing local Z values, UV seams
or repeated UVs, and irregular UV-to-position mapping can produce a
different shape. The shader modifies only local Z, regardless of how its
UVs are laid out or how the object is oriented in world space; at boundary
UVs the displacement is zero and Z does not change.

### Normals do not follow the displaced surface

The vertex shader transforms the **original** mesh normal, not a normal
recomputed from the displaced geometry. For a flat plane whose original
normals all point in the same direction, the resulting lighting can fail to
show the four slopes even when the geometry is visibly deformed.

In addition, `mat3(world) * normal` is generally not the correct normal
transform for a non-uniformly scaled or sheared world matrix. A robust
implementation would first obtain normals for the displaced surface, then
transform them with the inverse transpose of the world's linear `mat3`,
assuming that matrix is invertible. Flat faces need appropriate face
normals; averaging shared vertex normals instead produces a smoother look.
At the center and crease lines the ideal surface has no single unique
normal, so a rendering approach must choose how to handle those edges.

## Experiments

1. Set `pyramidHeight` to `0`, `2`, and `4` and compare the displacement
   along local `-Z`.
2. Try a negative `pyramidHeight` to reverse the direction of displacement.
3. Compare a four-corner quad with a subdivided grid. Confirm that a center
   vertex is displaced while boundary vertices are not.
4. Move the light and observe that the existing normal calculation may not
   illuminate the displaced sides as expected.
5. Change the UV layout or use UVs outside `[0, 1]`, and observe how the
   displacement follows UVs rather than local X and Y directly.
