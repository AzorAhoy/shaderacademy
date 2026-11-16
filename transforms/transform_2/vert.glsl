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

mat4 getRotationMatrix(float angle) {
    return mat4(
        cos(angle), 0.0, sin(angle), 0.0,
        0.0,        1.0, 0.0,        0.0,
       -sin(angle), 0.0, cos(angle), 0.0,
        0.0,        0.0, 0.0,        1.0
    );
}

void main() {
    vec4 modifiedPosition = vec4(position, 1.0);

    // Define PI as a constant
    const float PI = 3.14159265359;

    // TODO: Change the angle to rotate the cube with time:
    float angle = u_time * PI / 4.0;

    // Rotation matrix around the Y-axis
    mat4 rotation = getRotationMatrix(angle);

    // Apply the rotation to the vertex position
    modifiedPosition = rotation * modifiedPosition;
    
    // Apply the same rotation to the normal
    vec3 rotatedNormal = normalize(mat3(rotation) * normal);

    vec4 worldPos = world * modifiedPosition;

    vPosition = worldPos.xyz;
    vNormal = normalize(mat3(world) * rotatedNormal);
    v_uv = uv;
    
    gl_Position = worldViewProjection * modifiedPosition;
}
