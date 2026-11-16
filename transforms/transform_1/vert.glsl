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

void main() {
    vec4 worldPos = world * vec4(position, 1.0);

    vPosition = worldPos.xyz;
    vNormal = normalize(mat3(world) * normal);
    v_uv = uv;
        
    // Define PI as a constant
    const float PI = 3.14159265359;

    // Compute 45 degrees in radians (π/4)
    float angle = PI / 4.0;
    
    // Change your code from here:
    mat4 scale = mat4(
    2.0, 0.0, 0.0, 0.0,
    0.0, 2.0, 0.0, 0.0,
    0.0, 0.0, 2.0, 0.0,
    0.0, 0.0, 0.0, 1.0
    );
    vec4 scaled = scale * vec4(position, 1.0);
    
    gl_Position = worldViewProjection * scaled;
}
