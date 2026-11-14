#version 300 es
precision highp float;

in vec3 position;
in vec3 normal;
in vec2 uv;
in vec4 color;

in vec4 world0;
in vec4 world1;
in vec4 world2;
in vec4 world3;

in float instanceId;
in float instanceSeed;

uniform mat4 view;
uniform mat4 projection;

out vec3 vNormal;
out vec3 vPosition;
out vec2 v_uv;
flat out float vMaterialId;
out float vInstanceId;
out float vInstanceSeed;

void main() {
    mat4 instanceWorld = mat4(world0, world1, world2, world3);
    vec4 worldPos = instanceWorld * vec4(position, 1.0);
    vPosition = worldPos.xyz;
    vNormal = normalize(mat3(instanceWorld) * normal);
    v_uv = uv;
    vMaterialId = color.r;
    vInstanceId = instanceId;
    vInstanceSeed = instanceSeed;
    gl_Position = projection * view * worldPos;
}
