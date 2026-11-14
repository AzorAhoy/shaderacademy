Here is a detailed technical explanation of the provided shaders. You can save this content as a `.md` file (e.g., `SimpleReflection_Explanation.md`).

***

# Simple Reflection and Fresnel Shader Explanation

This shader demonstrates a fundamental "Simplified PBR" (Physically Based Rendering) model. It combines three key concepts: **Matte Shading** (diffuse), **Environment Reflections**, and the **Fresnel Effect**. 

While not as complex as a full Cook-Torrance PBR shader, it provides a much more realistic result than a simple "shiny" texture by making reflections stronger at glancing angles.

---

## 1. The Vertex Shader (`vert.glsl`)
Like the previous shaders, this performs standard 3D-to-2D transformation:
*   **Position:** Converts the 3D model coordinates into world space (`vPosition`).
*   **Normals:** Transforms surface normals into world space (`vNormal`) so lighting is calculated relative to the object's orientation.
*   **UVs:** Passes the texture coordinates to the fragment shader.

---

## 2. The Fragment Shader (`frag.glsl`)
This shader calculates the color of every pixel by simulating a surface that has both a base color and a reflective property.

### Step 1: The Procedural Environment (`skyColor`)
Before calculating the object's color, the shader defines the world around it.
*   **Ground & Sky:** It uses `mix` and `smoothstep` to create a horizon where there is a sandy ground at the bottom and a blue gradient sky at the top.
*   **The Sun:** It calculates a "sun" using `pow(..., 200.0)`. This creates a very sharp, bright circular highlight in the sky.
*   **Purpose:** This function provides the "reflection" that the object will eventually sample.

### Step 2: Basic Lighting Setup
The shader gathers the necessary vectors for lighting:
*   **`lightDir`**: The direction from the surface point to the light source.
*   **`viewDir`**: The direction from the surface point to the camera.
*   **`normal`**: The direction the surface is facing.

### Step 3: Matte Shading (The "Base")
```glsl
float diff = max(dot(normal, lightDir), 0.0);
vec3 base = (0.45 + diff) * lightColor * surfaceColor;
```
This is standard **Lambertian Diffuse** shading. 
*   It calculates the dot product of the normal and the light direction. 
*   If the surface faces the light, it is bright; if it faces away, it is dark.
*   This represents the "non-shiny" part of the material (like the matte part of a plastic toy).

### Step 4: Reflection Mapping
To make the object look reflective, the shader needs to know "what" is being reflected.
```glsl
vec3 reflectDir = reflect(-viewDir, normal);
vec3 reflection = skyColor(reflectDir);
```
*   **`reflect()`**: This function takes the camera's view direction and "bounces" it off the surface normal.
*   **`skyColor()`**: It then samples the environment we built in Step 1 using that reflected direction.
*   *Result:* If you look at the object, you see a "reflection" of the sky and sun.

### Step 5: The Fresnel Effect (Schlick's Approximation)
This is the most important step for realism. In the real world, surfaces become more reflective as you look at them from a sharper angle (like looking across a lake vs. looking straight down into the water).
```glsl
float cosTheta = max(dot(normal, viewDir), 0.0);
float fresnel = F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
```
*   **`F0` (0.04)**: This is the "base reflectivity." Most non-metals reflect about 4% of light when viewed head-on.
*   **`cosTheta`**: The angle between the camera and the surface.
*   **The Formula**: As the angle becomes shallower (moving toward the edges of an object), the `fresnel` value increases toward 1.0 (100% reflectivity).

### Step 6: Final Composition
```glsl
vec3 result = mix(base, reflection, fresnel);
```
The shader uses the `fresnel` value to blend the two components:
*   **At the center** (viewing head-on): `fresnel` is low, so the `base` (matte color) dominates.
*   **At the edges** (viewing at a grazing angle): `fresnel` is high, so the `reflection` (sky/sun) dominates.

---

## Summary Table

| Component | Effect | Real-World Equivalent |
| :--- | :--- | :--- |
| **Base (`diff`)** | Matte color | The actual paint/color of the object. |
| **Reflection** | Environment Map | What the object "sees" in its surroundings. |
| **Fresnel** | Angular Reflectivity | Why a road looks like a mirror at the horizon but like asphalt under your feet. |
| **SkyColor** | Procedural Background | A "fake" world created entirely in the shader code. |