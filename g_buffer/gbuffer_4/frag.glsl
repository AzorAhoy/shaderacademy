#version 300 es
precision highp float;

in vec3 vNormal;
in vec3 vPosition;
in vec2 v_uv;

uniform vec2 u_resolution;
uniform mat4 u_inverseViewProjection;
uniform float u_near;
uniform float u_far;

// 0: screen color, 1: depth written to G-Buffer
layout(location = 0) out vec4 fragColor;
layout(location = 1) out vec4 gBufferDepth;

void main() {
    // 1) Store non-linear depth in the G-Buffer
    float depth = gl_FragCoord.z;
    gBufferDepth = vec4(vec3(depth), 1.0);

    // 2) Reconstruct world-space position from depth
    // Convert screen coordinates to UV, then to NDC [-1,1]
    vec2 uv = gl_FragCoord.xy / u_resolution;
    vec2 ndc = uv * 2.0 - 1.0;

    // TODO: Convert depth buffer value to NDC z in [-1,1]
    // depth is in [0,1], produced from NDC z by: depth = ndcZ * 0.5 + 0.5
    float ndcZ = depth * 2.0 - 1.0;
    // depth = ndcZ * 0.5 + 0.5;

    // TODO: Build clip-space position
    vec4 clipPos = vec4(ndc, ndcZ, 1.0);

    // 4) Unproject to world space and divide by w
    vec4 worldPos = u_inverseViewProjection * clipPos;
    vec3 position = worldPos.xyz / worldPos.w;

    // Visualize world-space position as color using the ndc.xy and color.z
    vec3 color = position * 0.5 + 0.5;
    fragColor = vec4(ndc.xy, color.z, 1.0);
}

