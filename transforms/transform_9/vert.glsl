#version 300 es
precision highp float;

in vec3 position;
in vec3 normal;
in vec2 uv;

uniform mat4 world;
uniform mat4 worldView;
uniform mat4 worldViewProjection;

uniform float u_time;

out vec3 vNormal;
out vec3 vPosition;
out vec2 v_uv;

void main() {
    // TODO: define spiral angle based on y coordinate and u_time
    float spiralAngle = position.y * u_time;

    // TODO: Apply spiral: rotate X and Z around Y-axis while preserving the cube shape
    // Rotate the X and Z coordinates around Y-axis
    vec3 spiralPosition = position;
    float cosAngle = cos(spiralAngle);
    float sinAngle = sin(spiralAngle);
    float newX = position.x * cosAngle - position.z * sinAngle;
    float newZ = position.x * sinAngle + position.z * cosAngle;
    spiralPosition.x = newX;
    spiralPosition.z = newZ;

    vec4 worldPos = world * vec4(spiralPosition, 1.0);
    vPosition = worldPos.xyz;
    vNormal = normalize(mat3(world) * normal);
    v_uv = uv;
    gl_Position = worldViewProjection * vec4(spiralPosition, 1.0);
}
