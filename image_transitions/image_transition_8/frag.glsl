#version 300 es
precision mediump float;

uniform sampler2D u_texture;
uniform sampler2D u_noise;

uniform float u_time;
uniform float u_maxTime;

in vec2 v_uv;

out vec4 fragColor;

void main() {
    // TODO: sample the main texture
    fragColor = texture(u_texture, v_uv);
    // TODO: sample the noise texture (grayscale, use red channel)
    float noise = texture(u_noise, v_uv).r;

    // TODO: calculate progress from time
    float progress = u_time / u_maxTime;

    // TODO: create a mask using step() function
    // Pixels should disappear first where noise is darker (lower values)
    float mask = step(progress, noise);
    
    // TODO: apply the mask to fade out the image
    fragColor = mix(vec4(0.0), fragColor, mask);
}

