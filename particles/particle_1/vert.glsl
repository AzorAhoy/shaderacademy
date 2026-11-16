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

// Random function for particle positions
float random(vec3 seed) {
    return fract(sin(dot(seed, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

void main() {
    // Get the original position
    vec3 originalPos = position;
    
    // Create random particle positions in larger range
    vec3 randomOffset = vec3(
        random(originalPos + vec3(1.0, 0.0, 0.0)) * 2.0 - 1.0,
        random(originalPos + vec3(0.0, 1.0, 0.0)) * 2.0 - 1.0,
        random(originalPos + vec3(0.0, 0.0, 1.0)) * 2.0 - 1.0
    ) * 2.0; // Larger range for more spread
    
    vec3 newPos = originalPos + randomOffset;
    
    // Set point size for particle rendering
    gl_PointSize = 2.0;
    
    vec4 worldPos = world * vec4(newPos, 1.0);
    vPosition = worldPos.xyz;
    vNormal = normalize(mat3(world) * normal);
    v_uv = uv;
    
    gl_Position = worldViewProjection * vec4(newPos, 1.0);
} 