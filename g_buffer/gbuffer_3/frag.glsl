#version 300 es
precision highp float;

in vec3 vNormal;
in vec3 vPosition;
in vec2 v_uv;

// 0: screen color, 1: depth, 2: normal
layout(location = 0) out vec4 fragColor;
layout(location = 1) out vec4 gBufferDepth;
layout(location = 2) out vec4 gBufferNormal;

void main() {
    // Non-linear depth from the depth buffer in [0,1]
    float depth = gl_FragCoord.z;
    gBufferDepth = vec4(depth, depth, depth, depth);

    // TODO: get the world-space normal encoded into [0,1]. Fix the normal color to be the normal vector mapped to the range [0,1].
    vec3 normalColor = normalize(vNormal);
    gBufferNormal = vec4(normalColor * 0.5 + 0.5, 1.0);

    // Visualize the normal directly as color on screen
    fragColor = vec4(normalColor * 0.5 + 0.5, 1.0);
}


