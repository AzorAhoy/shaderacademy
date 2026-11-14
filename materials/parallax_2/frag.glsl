#version 300 es
precision highp float;

in vec3 vPosition;
in vec2 v_uv;

uniform vec3 u_cameraPosition;
uniform sampler2D u_texture;
uniform sampler2D u_heightMap;

out vec4 fragColor;

// Reads the height at an exact level of detail, which is reliable inside a loop.
// The smoothstep gives the stones flat tops and steep sides.
float sampleHeight(vec2 uv) {
    return smoothstep(0.15, 0.55, textureLod(u_heightMap, uv, 0.0).r);
}

void main() {
    // The surface frame of this flat plane, as in Parallax Mapping I
    vec3 tangent = vec3(1.0, 0.0, 0.0);
    vec3 bitangent = vec3(0.0, 0.0, 1.0);
    vec3 normal = vec3(0.0, 1.0, 0.0);

    vec3 viewDir = normalize(u_cameraPosition - vPosition);
    vec3 viewTS = vec3(dot(viewDir, tangent), dot(viewDir, bitangent), dot(viewDir, normal));

    // Much taller stones than in Parallax Mapping I
    float heightScale = 0.05;

    // How far the UVs move for a change in height of 1. The minimum keeps low angles stable.
    vec2 uvPerHeight = viewTS.xy / max(viewTS.z, 0.2) * heightScale;

    // The single-step solution from Parallax Mapping I, which breaks down with tall stones
    vec2 parallaxUV = v_uv + uvPerHeight * (sampleHeight(v_uv) - 0.5);

    // Replace the line above with a search along the view ray:

    // TODO 1: Divide the height range into 16 layers, and compute uvStep, the UV step between layers
    const int numLayers = 16;
    float layerHeight = 1.0 / float(numLayers);
    vec2 uvStep = uvPerHeight * layerHeight;
    // TODO 2: Start at a rayHeight of 1. Compute the UV there, using the formula above with a height of 1.
    float rayHeight = 1.0;
    vec2 uv = v_uv + uvPerHeight * 0.5;
    // TODO 3: In a loop, stop when rayHeight <= sampleHeight(uv). Otherwise, go down one layer.
    for (int i = 0; i < numLayers; i++) {
        if (rayHeight <= sampleHeight(uv)) {
            break;
        }
        rayHeight -= layerHeight;
        uv -= uvStep;
    }
    // TODO 4: Interpolate between the last two points to find where the ray crossed the surface.
    vec2 previousUV = uv + uvStep;
    float gapBefore = (rayHeight + layerHeight) - sampleHeight(previousUV);
    float gapAfter = sampleHeight(uv) - rayHeight;
    float t = gapBefore / (gapBefore + gapAfter);
    parallaxUV = mix(previousUV, uv, t);
    // Use the original UV derivatives, because parallaxUV jumps at the edges of the stones
    vec3 color = textureGrad(u_texture, parallaxUV, dFdx(v_uv), dFdy(v_uv)).rgb;
    fragColor = vec4(color, 1.0);
}
