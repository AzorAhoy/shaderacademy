#version 300 es
precision highp float;

in vec3 position;
in vec3 normal;
in vec2 uv;

uniform mat4 world;
uniform mat4 worldView;
uniform mat4 worldViewProjection;
uniform float u_time;
uniform float u_maxTime;

out vec3 vNormal;
out vec3 vPosition;
out vec2 v_uv;
flat out int vPointGroup;

void main() {
    // TODO: Use gl_VertexID to determine which point group to assign
    int vertexId = gl_VertexID;
    int triangleIndex = vertexId % 3;

    vec3 originalPos = position;
    vec3 newPos = originalPos; // Default to original position
    vPointGroup = 0; // Default point group
    
    vec3 trianglePositions[3] = vec3[3](
        vec3(-2.0, -1.0, 0.0),  // Bottom left
        vec3(2.0, -1.0, 0.0),   // Bottom right
        vec3(0.0, 2.0, 0.0)     // Top
    );

    // TODO: Animate particles moving between original position and triangle positions
    // TODO: Pass point group to fragment shader for coloring
    float progress = u_time / u_maxTime;
    newPos = mix(originalPos, trianglePositions[triangleIndex], progress);   
    vPointGroup = triangleIndex;
    // Set point size for particle rendering
    gl_PointSize = 1.5;
    
    vec4 worldPos = world * vec4(newPos, 1.0);
    vPosition = worldPos.xyz;
    vNormal = normalize(mat3(world) * normal);
    v_uv = uv;
    
    gl_Position = worldViewProjection * vec4(newPos, 1.0);
}
