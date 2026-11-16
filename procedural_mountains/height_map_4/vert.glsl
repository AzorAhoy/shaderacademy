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
    // Create a copy of the position that we'll modify
    vec3 modifiedPosition = position;

    // Make sure you use these parameters:
    float gridCount = 4.0;
    float pyramidHeight = 1.5;

    // TODO: Displace modifiedPosition.z to create a 4x4 grid of pyramids:
    vec2 cellUV = fract(uv * gridCount);
    vec2 distFromCenter = abs(cellUV  - 0.5);
    float height = -1.0 + max(distFromCenter.x, distFromCenter.y) * 2.0;
    modifiedPosition.z += height * pyramidHeight;

    vec4 worldPos = world * vec4(modifiedPosition, 1.0);

    vPosition = worldPos.xyz;
    vNormal = normalize(mat3(world) * normal);
    v_uv = uv;

    gl_Position = worldViewProjection * vec4(modifiedPosition, 1.0);
}
