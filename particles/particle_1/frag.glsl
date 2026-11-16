#version 300 es
precision highp float;

in vec3 vNormal;
in vec3 vPosition;
in vec2 v_uv;

uniform vec3 lightPosition;
uniform vec3 lightColor;
uniform vec3 objectColor;
uniform float shininess;

out vec4 fragColor;

// Random function for particle colors
float random(vec3 seed) {
    return fract(sin(dot(seed, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

// Color function for particles
vec3 getParticleColor(vec3 pos) {
    float r = step(0.5, random(pos + vec3(1.0, 0.0, 0.0)));
    float g = step(0.5, random(pos + vec3(0.0, 1.0, 0.0)));
    float b = step(0.5, random(pos + vec3(0.0, 0.0, 1.0)));
    return vec3(r, g, b);
}

void main() {
    vec3 color = getParticleColor(vPosition);
    fragColor = vec4(color, 1.0);
} 