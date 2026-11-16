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
    // Create animated spiral deformation: rotate around Y-axis based on Y-coordinate and u_time
    float spiralAngle = position.y * u_time;
    
    vec3 spiralPosition = position;
    
    // Apply spiral: rotate X and Z around Y-axis while preserving the cube shape
    float cosAngle = cos(spiralAngle);
    float sinAngle = sin(spiralAngle);
    
    // Rotate the X and Z coordinates around Y-axis
    float newX = spiralPosition.x * cosAngle - spiralPosition.z * sinAngle;
    float newZ = spiralPosition.x * sinAngle + spiralPosition.z * cosAngle;
    
    spiralPosition.x = newX;
    spiralPosition.z = newZ;
    
    // TODO: Apply the same rotation to normals for correct lighting
    float normalX = normal.x * cosAngle - normal.z * sinAngle;
    float normalZ = normal.x * sinAngle + normal.z * cosAngle;
    vec3 rotatedNormal = vec3(normalX, normal.y, normalZ);
    
    vec4 worldPos = world * vec4(spiralPosition, 1.0);
    vPosition = worldPos.xyz;
    vNormal = normalize(mat3(world) * rotatedNormal);
    v_uv = uv;
    gl_Position = worldViewProjection * vec4(spiralPosition, 1.0);
}
