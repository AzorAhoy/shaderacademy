#version 300 es
precision highp float;

in vec3 vNormal;
in vec3 vPosition;
in vec2 v_uv;

// Explicit location for the main color output so this shader
// is ready for future Multiple Render Target (MRT) use.
layout(location = 0) out vec4 fragColor;
// Second MRT output: a depth buffer stored as a texture.
layout(location = 1) out vec4 gBufferDepth;

void main() {
    // TODO: get the non-linear depth from the depth buffer in [0,1]
    float depth = gl_FragCoord.z;

    // Store depth into the G-Buffer texture using all four channels.
    gBufferDepth = vec4(depth, depth, depth, depth);

    // Visualize depth on screen.
    fragColor = vec4(1.0 - depth, 1.0 - depth, 1.0 - depth, 1.0);
}


