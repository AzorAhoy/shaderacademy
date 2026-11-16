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
    // TODO: Build a uniform scale matrix with 0.5 on the diagonal
    mat4 scale = mat4(
    0.5, 0.0, 0.0, 0.0,
    0.0, 0.5, 0.0, 0.0,
    0.0, 0.0, 0.5, 0.0,
    0.0, 0.0, 0.0, 1.0
    );
    vec4 scaledPosition = scale * vec4(position, 1.0);

    // Keep output valid without scaling for now
    vec4 worldPos = world * vec4(position, 1.0);
    vPosition = worldPos.xyz;
    vNormal = normalize(mat3(world) * normal);
    v_uv = uv;
    gl_Position = worldViewProjection * scaledPosition;
}


