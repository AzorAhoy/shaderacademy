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

mat4 getRotationMatrixX(float angle) {
    return mat4(
        1.0, 0.0,        0.0,       0.0,
        0.0, cos(angle), -sin(angle), 0.0,
        0.0, sin(angle),  cos(angle), 0.0,
        0.0, 0.0,        0.0,       1.0
    );
}

void main() {
    // TODO: Create scale (1.5x) and rotate (135°) then apply to position
    const float PI = 3.14159265359;
    float angle = 3.0 * PI / 4.0;
    mat4 scale = mat4(
    1.5, 0.0, 0.0, 0.0,
    0.0, 1.5, 0.0, 0.0,
    0.0, 0.0, 1.5, 0.0,
    0.0, 0.0, 0.0, 1.0
    );
    scale *= getRotationMatrixX(angle);
    vec4 scaledPosition = scale * vec4(position, 1.0);

    vec4 worldPos = world * vec4(position, 1.0);
    vPosition = worldPos.xyz;
    vNormal = normalize(mat3(world) * normal);
    v_uv = uv;
    gl_Position = worldViewProjection * scaledPosition;
}


