#version 300 es
precision mediump float;

uniform sampler2D u_texture;
uniform vec2 u_mousePosition;
uniform float u_time;
in vec2 v_uv;
out vec4 fragColor;

void main() {    
    float dist = distance(v_uv, u_mousePosition);
    float radius = 0.4;
    vec4 backgroundColor = vec4(0.1, 0.1, 0.1, 1.0);
    
    // Constants for the wave effect
    float waveSpeed = 2.0;
    float waveFrequency = 8.0;
    float waveAmplitude = 0.1;
    
    // Create multiple wave rings that pulse outward
    float wave1 = sin(dist * waveFrequency - u_time * waveSpeed) * waveAmplitude;
    float wave2 = sin(dist * waveFrequency * 0.5 - u_time * waveSpeed * 0.7) * waveAmplitude * 0.7;
    float wave3 = sin(dist * waveFrequency * 0.3 - u_time * waveSpeed * 0.5) * waveAmplitude * 0.5;
    
    // Combine waves for more complex water effect
    float combinedWave = wave1 + wave2 + wave3;
    
    // TODO: Create a soft falloff based on distance
    // float falloff = 0.0;
    float falloff = 1.0 - smoothstep(0.0, radius, dist);

    // Apply the wave effect to the texture
    vec2 waveOffset = vec2(combinedWave * 0.02, combinedWave * 0.02);

    // TODO: Apply the wave effect to the texture (take into account the waveOffset)
    //vec4 textureColor = vec4(0.0);
    vec4 textureColor = texture(u_texture, v_uv + waveOffset);

    
    // TODO: Mix texture with background based on wave intensity
    float waveIntensity = abs(combinedWave) * falloff;

    fragColor = mix(backgroundColor, textureColor, waveIntensity + 0.3);
}