Here is a detailed technical explanation of the provided shaders. You can save this content as a `.md` file (e.g., `PBR_Explanation.md`).

***

# Physically Based Rendering (PBR) Shader Explanation

These shaders implement a **Physically Based Rendering (PBR)** pipeline using the **Cook-Torrance BRDF** (Bidirectional Reflectance Distribution Function). This is the industry standard for achieving photorealistic materials in modern game engines (like Unreal Engine or Unity).

Unlike "legacy" lighting (like Phong or Blinn-Phong), PBR simulates how light interacts with physical surfaces by accounting for energy conservation, microfacet theory, and the Fresnel effect.

---

## 1. The Vertex Shader (`vert.glsl`)
The vertex shader performs the standard transformation from 3D model space to 2D screen space.

*   **World Position:** It multiplies the raw `position` by the `world` matrix to determine where the object sits in the 3D scene.
*   **Normal Transformation:** It transforms the surface `normal` into world space so that the lighting calculations in the fragment shader are consistent with the object's orientation.
*   **Output:** It passes the world position (`vPosition`), the world normal (`vNormal`), and the texture coordinates (`v_uv`) to the fragment shader.

---

## 2. The Fragment Shader (`frag.glsl`)
This shader calculates the color of every pixel by simulating the behavior of light on a surface with specific material properties.

### A. Material Properties
The shader first defines what the "object" actually is:
*   **Metallic:** The code determines if the surface is metal or a non-metal (dielectric). Metal reflects the color of the material, while non-metals have a constant base reflectivity.
*   **Albedo:** The base color of the surface (e.g., the "red" of the plastic or the "yellow" of the gold).
*   **Roughness:** How "smooth" the surface is. A roughness of `0.0` is a perfect mirror; `1.0` is a completely matte, dull surface.

### B. The "Big Three" PBR Math Terms
The core of the Cook-Torrance model relies on three mathematical functions that describe how light interacts with **microfacets** (the microscopic bumps on a surface).

#### 1. Distribution Function (**D** - GGX)
```glsl
float distributionGGX(float NdotH, float roughness)
```
This calculates the alignment of microfacets. It determines the size and shape of the **specular highlight**.
*   If the surface is smooth, the highlight is small and sharp.
*   If the surface is rough, the highlight is spread out and blurry.

#### 2. Geometry Function (**G** - Smith's Method)
```glsl
float geometrySchlickGGX(float NdotX, float roughness)
float geometrySmith(float NdotV, float NdotL, float roughness)
```
This simulates "self-shadowing." On a rough surface, some microfacets will block light from hitting other microfacets, or block the viewer from seeing them. This function ensures the surface doesn't look unnaturally bright at sharp angles.

#### 3. Fresnel Equation (**F** - Schlick's Approximation)
```glsl
vec3 fresnelSchlick(float cosTheta, vec3 F0)
```
This calculates the ratio of light that is reflected vs. refracted. 
*   **Key Insight:** Reflections become much stronger at "grazing angles" (when you look at a surface from a very shallow side angle). 
*   **F0:** This represents the base reflectivity of the surface (the reflection at a direct 0-degree angle).

### C. The Cook-Torrance Formula
The `computeLight` function combines these three terms into the final specular reflection:

$$\text{Specular} = \frac{D \cdot G \cdot F}{4 \cdot (N \cdot V) \cdot (N \cdot L)}$$

It then calculates the **Diffuse** component. It follows the law of **Energy Conservation**: 
*   Light that is reflected cannot also be diffused.
*   Metals have no diffuse component (they absorb all light that isn't reflected).

### D. Environment and Ambient Lighting
To prevent the shadows from being pitch black, the shader adds two types of ambient light:
1.  **Sky Color:** It uses `reflect(-V, N)` to find the direction of the sky and uses `skyColor` to simulate a gradient (darker at the bottom, lighter at the top).
2.  **Environment Reflection:** It multiplies the sky color by the **Fresnel** term, meaning you see more of the sky reflection at glancing angles.

### E. Post-Processing (Tone Mapping & Gamma Correction)
The final colors calculated by the PBR math can be much brighter than what a computer monitor can display (HDR values). 

1.  **Tone Mapping:** `color / (color + vec3(1.0))`
    *   This "squashes" the high-dynamic-range values into a 0.0 to 1.0 range, preventing bright areas from looking like "blown out" white blobs.
2.  **Gamma Correction:** `pow(color, vec3(1.0 / 2.2))`
    *   Monitors do not display light linearly. This step adjusts the colors so they look correct to the human eye.

---

## Summary Table

| Component | Purpose | Visual Result |
| :--- | :--- | :--- |
| **Albedo** | Base Color | The "paint" of the object. |
| **Roughness** | Microfacet Scattering | Controls blurriness of reflections. |
| **Metallic** | Conductivity | Controls if the object reflects color (metal) or white (plastic). |
| **D (GGX)** | Distribution | Shapes the size of the shiny spot. |
| **G (Smith)** | Geometry | Shadows the tiny bumps on the surface. |
| **F (Fresnel)** | Reflection Angle | Makes edges "shinier" than the center. |
| **Tone Mapping**| HDR to LDR | Keeps the bright lights from "breaking" the image. |