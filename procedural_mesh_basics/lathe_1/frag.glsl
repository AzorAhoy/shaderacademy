#version 300 es
precision highp float;

in vec3 vNormal;
in vec2 v_uv;

out vec4 fragColor;

void main() {
    // Painted bands around the vase, and stripes going up it
    float bands = step(0.5, fract(v_uv.y * 6.0));
    float stripes = step(0.5, fract(v_uv.x * 16.0));
    vec3 base = mix(vec3(0.72, 0.33, 0.18), vec3(0.9, 0.78, 0.58), bands);
    base = mix(base, base * 0.55, stripes * (1.0 - bands));

    vec3 normal = normalize(vNormal);
    float diff = max(dot(normal, normalize(vec3(0.5, 0.8, 0.6))), 0.0);
    fragColor = vec4(base * (0.3 + 0.8 * diff), 1.0);
}
