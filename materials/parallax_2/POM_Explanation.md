Here is a detailed, step-by-step technical explanation of the provided shaders. You can save this content as a `.md` file (e.g., `POM_Explanation.md`).

***

# Parallax Occlusion Mapping (POM) Technical Explanation

This project implements **Parallax Occlusion Mapping (POM)**, a high-end shading technique used to simulate 3D geometry on a 2D surface. Unlike "Normal Mapping" (which only simulates lighting) or "Standard Parallax Mapping" (which only shifts textures), **POM** simulates actual depth by "ray marching" through a height map to find where a view ray would intersect a 3D surface.

## 1. The Vertex Shader (`vert.glsl`)
The vertex shader is the "foundation." Its job is to take the raw 3D model data and position it correctly in the 3D scene.

### Key Operations:
1.  **World Transformation:** 
    It takes the `position` of each vertex and multiplies it by the `world` matrix to find its location in the 3D world (`vPosition`).
2.  **Normal Calculation:**
    It transforms the `normal` (the direction the surface faces) into world space so that lighting can be calculated correctly.
3.  **UV Mapping:**
    It passes the `uv` coordinates directly to the fragment shader. These coordinates tell the GPU which part of the texture image to look at for each pixel.
4.  **Projection:**
    It calculates `gl_Position` using the `worldViewProjection` matrix to determine where the vertex appears on your 2D screen.

---

## 2. The Fragment Shader (`frag.glsl`)
This is where the complex math of Parallax Occlusion Mapping happens. It calculates the final color of every pixel.

### Step 1: Establishing the Coordinate System
To calculate depth, the shader needs to know which way is "up," "left," and "out" from the surface.
*   **Tangent Space:** It defines three vectors:
    *   `tangent`: Horizontal axis.
    *   `bitangent`: Depth axis (pointing "out" of the surface).
    *   `normal`: Vertical axis.
*   **View Vector (`viewTS`):** It calculates the direction from the camera to the current pixel, but converts it into the "Tangent Space." This ensures that as you move your head, the depth effect reacts correctly to your perspective.

### Step 2: Height Sampling (`sampleHeight`)
The shader uses a **Height Map** (a grayscale image where white is high and black is low).
```glsl
float sampleHeight(vec2 uv) {
    return smoothstep(0.15, 0.55, textureLod(u_heightMap, uv, 0.0).r);
}
```
*   **`textureLod`**: Used to sample the height map without causing "aliasing" (shimmering) during the loop.
*   **`smoothstep`**: This is a crucial artistic choice. It sharpens the tops of the stones and makes the sides steeper, making the 3D effect look more "carved" and less like a soft blob.

### Step 3: The Ray Marching Loop (The Core of POM)
Instead of just shifting the UVs once, the shader "marches" a ray into the surface to see where it hits.

1.  **Layering:** It divides the depth into 16 layers (`numLayers`).
2.  **UV Step:** It calculates `uvStep`, which is how much the UV coordinates should shift for every "layer" of depth we move down.
3.  **The Loop:**
    *   It starts at the very top of the height map (`rayHeight = 1.0`).
    *   It checks the height of the stone at the current UV position.
    *   If the `rayHeight` is still higher than the stone's surface, it moves the UV coordinate slightly and drops the `rayHeight` by one layer.
    *   It repeats this until `rayHeight` is finally lower than the stone's surface (meaning the ray has "entered" the stone).

### Step 4: Linear Interpolation (Occlusion)
Because the loop jumps between layers, the exact intersection point might be "between" two layers. The shader calculates the exact point of impact to prevent the surface from looking like it's made of "steps."

```glsl
float gapBefore = (rayHeight + layerHeight) - sampleHeight(previousUV);
float gapAfter = sampleHeight(uv) - rayHeight;
float t = gapBefore / (gapBefore + gapAfter);
parallaxUV = mix(previousUV, uv, t);
```
*   It calculates how far the ray was from the surface before the hit (`gapBefore`) and after the hit (`gapAfter`).
*   It uses `mix` to find the precise floating-point coordinate between those two points.

### Step 5: Final Rendering
Finally, the shader applies the calculated `parallaxUV` to the actual texture.
```glsl
vec3 color = textureGrad(u_texture, parallaxUV, dFdx(v_uv), dFdy(v_uv)).rgb;
```
*   **`textureGrad`**: This is used because the parallax effect causes "UV jumping" at the edges of objects. `textureGrad` helps the GPU calculate smooth gradients so the edges of the stones don't look jagged or pixelated.

---

## Summary Comparison

| Feature | Standard Parallax | Parallax Occlusion (POM) |
| :--- | :--- | :--- |
| **Method** | Simple UV Offset | Ray Marching (Looping) |
| **Depth** | Shallow, "fake" depth | Deep, realistic depth |
| **Occlusion** | No (textures "ghost" through each other) | **Yes** (stones correctly overlap/hide each other) |
| **Visual Quality** | Good for bricks/floor | Best for large stones, cracks, and deep carvings |
| **Performance** | Very Fast | Slower (requires 16 iterations per pixel) |