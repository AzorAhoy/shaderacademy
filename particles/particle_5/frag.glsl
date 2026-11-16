#version 300 es
precision highp float;

in vec3 vNormal;
in vec3 vPosition;
in vec2 v_uv;

uniform vec3 lightPosition;
uniform vec3 lightColor;
uniform vec3 objectColor;
uniform float shininess;
uniform sampler2D u_texture;

out vec4 fragColor;

void main() {
    // TODO: Sample the texture and output it directly
    vec4 texColor = texture(u_texture, v_uv);
    fragColor = texColor;
}
