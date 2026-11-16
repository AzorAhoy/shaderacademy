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
    // TODO: Compute a time-based scale factor using sin(u_time). It should be between 0.5 and 1.5.
    float s = 1.0 + 0.5 * sin(u_time);
    mat4 scale = mat4(
    s,   0.0, 0.0, 0.0,
    0.0, s,   0.0, 0.0,
    0.0, 0.0, s,   0.0,
    0.0, 0.0, 0.0, 1.0
    );
    vec4 scaledPosition = scale * vec4(position, 1.0);
    
    vec4 worldPos = world * vec4(position, 1.0);
    vPosition = worldPos.xyz;
    vNormal = normalize(mat3(world) * normal);
    v_uv = uv;
    gl_Position = worldViewProjection * scaledPosition;
}


