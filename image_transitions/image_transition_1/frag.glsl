#version 300 es
precision mediump float;

uniform sampler2D u_texture;

uniform float u_time;
uniform float u_maxTime;

in vec2 v_uv;

out vec4 fragColor;

void main() {
    fragColor = texture(u_texture, v_uv);
    float progress = u_time / u_maxTime;
    float mask = step(progress, fragColor.r);
    fragColor.a *= mask;
}
