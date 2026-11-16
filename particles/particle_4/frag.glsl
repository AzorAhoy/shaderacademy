#version 300 es
precision highp float;

in vec3 vNormal;
in vec3 vPosition;
in vec2 v_uv;
flat in int vPointGroup;

uniform vec3 lightPosition;
uniform vec3 lightColor;
uniform vec3 objectColor;
uniform float shininess;

out vec4 fragColor;

void main() {
    // TODO: Color particles based on their point group (vPointGroup)
    // Use the same logic as vertex shader - gl_VertexID % 3
    
    vec3 color = vec3(1.0, 1.0, 1.0); // Default white color
    if(vPointGroup == 0) {
        color = vec3(1.0, 0.0, 0.0); // Red for bottom left
    } else if(vPointGroup == 1) {
        color = vec3(0.0, 1.0, 0.0); // Green for bottom right
    } else {
        color = vec3(0.0, 0.0, 1.0); // Blue for top
    }
    fragColor = vec4(color, 1.0);
}
