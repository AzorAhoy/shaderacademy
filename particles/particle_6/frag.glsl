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
    // TODO: Sample the texture using v_uv
    // TODO: Calculate distance from camera using vPosition
    // TODO: Convert distance to opacity (further = more transparent)
    float maxDistance = 10.0; // Maximum distance from camera, for full opacity
    float distance = length(vPosition);
    float normalizedDistance = clamp(distance / maxDistance, 0.0, 1.0);

    vec4 texColor = texture(u_texture, v_uv);
    float opacity = 1.0 - normalizedDistance;
    fragColor = vec4(texColor.rgb, texColor.a * opacity);
}
