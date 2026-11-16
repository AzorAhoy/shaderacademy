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

mat4 getRotationMatrixX(float angle) {
    return mat4(
        1.0, 0.0,        0.0,       0.0,
        0.0, cos(angle), -sin(angle), 0.0,
        0.0, sin(angle),  cos(angle), 0.0,
        0.0, 0.0,        0.0,       1.0
    );
}

void main() {
    // Define PI as a constant
    const float PI = 3.14159265359;

    // TODO: Compute the angle in radians using time (e.g., u_time * PI / 4.0)
    float angle = u_time * PI / 4.0;

    // TODO: Build the rotation matrix around the X-axis using getRotationMatrixX(angle)
    mat4 rotation = getRotationMatrixX(angle);

    // TODO: Apply the rotation to the vertex position
    vec4 modifiedPosition = rotation * vec4(position, 1.0);
    // TODO: Rotate the normal with the same rotation

    // Keep output valid without rotation for now
    vec4 worldPos = world * modifiedPosition;
    vPosition = worldPos.xyz;
    vec3 rotatedNormal = normalize(mat3(rotation) * normal);
    vNormal = normalize(mat3(world) * rotatedNormal);
    v_uv = uv;
    gl_Position = worldViewProjection * modifiedPosition;
}


