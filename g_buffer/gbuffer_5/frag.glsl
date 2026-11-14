#version 300 es
precision highp float;

in vec2 vUV;

uniform sampler2D gBufferDepth;
uniform sampler2D gBufferNormal;
uniform sampler2D gBufferAlbedo;
uniform mat4 u_inverseViewProjection;

out vec4 fragColor;

const int NUM_LIGHTS = 3;
const vec3 LIGHT_POSITIONS[NUM_LIGHTS] = vec3[](
    vec3(5.0, -1.5, -2.0),
    vec3(-2.0, -1.5, 5.0),
    vec3(-3.0, 1.0, -3.0)
);
const vec3 LIGHT_COLORS[NUM_LIGHTS] = vec3[](
    vec3(1.6, 0.4, 0.3),
    vec3(0.3, 1.4, 0.5),
    vec3(0.4, 0.6, 1.8)
);

void main() {
    vec4 albedo = texture(gBufferAlbedo, vUV);

    // Nothing was drawn here, so there is nothing to light
    if (albedo.a == 0.0) {
        fragColor = vec4(0.05, 0.05, 0.07, 1.0);
        return;
    }

    // TODO 1: Read the depth, and rebuild the world position as in Geometry Buffer IV.
    // vUV is already this pixel's position on the screen, in the 0 to 1 range.
    float depth = texture(gBufferDepth, vUV).r;
    vec4 clipPos = vec4(vUV * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 worldPos = u_inverseViewProjection * clipPos;
    vec3 position = worldPos.xyz / worldPos.w;

    // TODO 2: Read the normal, and decode it from the 0 to 1 range back to -1 to 1
    vec3 normal = normalize(texture(gBufferNormal, vUV).rgb * 2.0 - 1.0);

    vec3 color = albedo.rgb * 0.04;

    // TODO 3: For each light, add albedo * lightColor * diff * attenuation to color, using:
    // float attenuation = 1.0 / (1.0 + 0.03 * dist * dist);
    for (int i = 0; i < NUM_LIGHTS; i++) {
        vec3 toLight = LIGHT_POSITIONS[i] - position;
        float dist = length(toLight);
        float diff = max(dot(normal, toLight / dist), 0.0);
        float attenuation = 1.0 / (1.0 + 0.03 * dist * dist);
        color += albedo.rgb * LIGHT_COLORS[i] * diff * attenuation;
    }

    fragColor = vec4(color, 1.0);
}
