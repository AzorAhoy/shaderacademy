#version 300 es
precision highp float;

in vec3 vNormal;
in vec3 vPosition;
in vec2 v_uv;

uniform vec3 lightPosition;
uniform vec3 lightColor;
uniform vec3 u_cameraPosition;

out vec4 fragColor;

const float PI = 3.14159265359;

// A soft version of the previous environment, because rough surfaces blur reflections
vec3 skyColor(vec3 dir) {
    return mix(vec3(0.2, 0.17, 0.15), vec3(0.9, 0.9, 0.95), smoothstep(-0.6, 0.6, dir.y));
}

// TODO 1: D, the GGX distribution of microfacets aligned with the half vector.
// Use a = roughness * roughness, and a2 = a * a.
float distributionGGX(float NdotH, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    return a2 / (PI * pow(pow(NdotH, 2.0) * (a2 - 1.0) + 1.0, 2.0));
}

// TODO 2: G for one direction, using Schlick-GGX with k = (roughness + 1)^2 / 8
float geometrySchlickGGX(float NdotX, float roughness) {
    float k = pow(roughness + 1.0, 2.0) / 8.0;
    return NdotX / (NdotX * (1.0 - k) + k);
}

// TODO 3: Smith's method: multiply geometrySchlickGGX for both NdotV and NdotL
float geometrySmith(float NdotV, float NdotL, float roughness) {
    return geometrySchlickGGX(NdotV, roughness) 
    * geometrySchlickGGX(NdotL, roughness);
}

// TODO 4: F, Schlick's approximation from the previous challenge, with a vec3 F0
vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

// The light arriving from one light source
vec3 computeLight(vec3 lightPos, float intensity, vec3 N, vec3 V, vec3 F0, vec3 albedo, float metallic, float roughness) {
    vec3 L = normalize(lightPos - vPosition);
    vec3 H = normalize(V + L);

    float NdotV = max(dot(N, V), 0.001);
    float NdotL = max(dot(N, L), 0.0);
    float NdotH = max(dot(N, H), 0.0);
    float HdotV = max(dot(H, V), 0.0);

    float D = distributionGGX(NdotH, roughness);
    float G = geometrySmith(NdotV, NdotL, roughness);
    vec3 F = fresnelSchlick(HdotV, F0);

    // TODO 6: Combine D, G and F using the Cook-Torrance formula.
    // Keep the denominator above 0.001 to avoid dividing by zero.
    vec3 specular = (D*G*F) / max(4.0 * NdotV * NdotL, 0.001);

    // TODO 7: Light that reflects can't also diffuse, and metals don't diffuse at all
    vec3 kD = (vec3(1.0) - F) * (1.0 - metallic);

    vec3 radiance = lightColor * intensity;
    return (kD * albedo / PI + specular) * radiance * NdotL;
}

void main() {
    // One half of the sphere is red plastic, and the other half is gold
    float metallic = step(0.0, vPosition.x - vPosition.z);
    vec3 albedo = mix(vec3(0.7, 0.04, 0.03), vec3(1.0, 0.65, 0.2), metallic);
    float roughness = 0.45;

    vec3 N = normalize(vNormal);
    vec3 V = normalize(u_cameraPosition - vPosition);
    float NdotV = max(dot(N, V), 0.001);

    // TODO 5: Use 0.04 for non-metals and albedo for metals, blending with metallic
    vec3 F0 = mix(vec3(0.04), albedo, metallic);

    // A key light near the camera, and a back light that creates grazing angles
    vec3 direct = computeLight(lightPosition, 2.5, N, V, F0, albedo, metallic, roughness);
    direct += computeLight(vec3(-4.0, 5.0, -4.0), 6.0, N, V, F0, albedo, metallic, roughness);

    // A simple stand-in for light arriving from the rest of the environment
    vec3 environment = skyColor(reflect(-V, N)) * fresnelSchlick(NdotV, F0);
    vec3 ambient = 0.03 * albedo * (1.0 - metallic) + environment;

    // Tone map the bright values into the display range, then apply gamma correction
    vec3 color = direct + ambient;
    color = color / (color + vec3(1.0));
    color = pow(color, vec3(1.0 / 2.2));
    fragColor = vec4(color, 1.0);
}
