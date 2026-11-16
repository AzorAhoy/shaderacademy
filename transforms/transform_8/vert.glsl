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
    // TODO: Apply taper transformation to the cube
    // Taper Y-axis based on Z-coordinate with factor 0.95, remember to add 1.0 to the factor
    float taperFactor = 0.95;
    vec3 taperedPosition = position;
    taperedPosition.y *= (1.0 + taperFactor * position.z);
    
    vec4 worldPos = world * vec4(position, 1.0);
    vPosition = worldPos.xyz;
    vNormal = normalize(mat3(world) * normal);
    v_uv = uv;
    gl_Position = worldViewProjection * vec4(taperedPosition, 1.0);
}
