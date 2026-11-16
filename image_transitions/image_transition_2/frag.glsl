#version 300 es
precision mediump float;

uniform sampler2D u_texture;

uniform float u_time;
uniform float u_maxTime;

in vec2 v_uv;

out vec4 fragColor;

void main() {
    // fragColor = texture(u_texture, v_uv);

    // Creates a value that increases from 0 to 0.5 over the animation duration, controlling the visual change.
    float offsetMultiplier = u_time / (u_maxTime * 2.0);
    vec4 currentFragColor = texture(u_texture, v_uv);
    vec2 x = currentFragColor.rg * offsetMultiplier;
    fragColor = texture(u_texture, v_uv + x);
}
