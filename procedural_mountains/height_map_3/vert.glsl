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

    // Make sure you use this parameter:
    float pyramidHeight = 4.0;

    // TODO: Displace modifiedPosition.z to create a single pyramid:

    // Measure distance from the UV center (0.5, 0.5)
    vec2 distFromCenter = abs(uv - 0.5);
    // Use Chebyshev distance so iso-contours are squares (pyramid sides)
    // Height is -1.0 at the center (peak, negative Z = up) and 0.0 at the edges.
    float height = -1.0 + max(distFromCenter.x, distFromCenter.y) * 2.0;
    // Apply the displacement along Z
    modifiedPosition.z += height * pyramidHeight;
    // Compute worldPos with the modified position
    vec4 worldPos = world * vec4(modifiedPosition, 1.0);

    // Set vPosition, transform/normalize the normal, and pass v_uv
    vPosition = worldPos.xyz;
    vNormal = normalize(mat3(world) * normal);
    v_uv = uv;
    
    // Output final clip-space position
    gl_Position = worldViewProjection * vec4(modifiedPosition, 1.0);
}
