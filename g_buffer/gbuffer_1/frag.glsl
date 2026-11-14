#version 300 es
precision highp float;

in vec3 vNormal;
in vec3 vPosition;
in vec2 v_uv;

// Explicit location for the main color output so this shader
// is ready for future Multiple Render Target (MRT) use.
layout(location = 0) out vec4 fragColor;

void main() {
    // TODO: Visualize world-space position as a colorful output.
    // Map from approximately [-1,1] to [0,1] for display (use vPosition)
    vec3 positionColor = vPosition * 0.5 + 0.5;
    // Temporary placeholder color:
    fragColor = vec4(positionColor, 1.0);
}

