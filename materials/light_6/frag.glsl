#version 300 es
precision highp float;

in vec3 vNormal;
in vec3 vPosition;
in vec2 v_uv;

uniform vec3 lightPosition;
uniform vec3 lightColor;
uniform vec3 u_cameraPosition;

out vec4 fragColor;

// A simple procedural environment: sand below the horizon, a blue gradient above it, and a sun
vec3 skyColor(vec3 dir) {
    vec3 sky = mix(vec3(0.45, 0.75, 1.0), vec3(0.15, 0.35, 0.85), smoothstep(0.0, 0.5, dir.y));
    vec3 ground = vec3(0.95, 0.72, 0.4);
    vec3 color = mix(ground, sky, smoothstep(-0.02, 0.02, dir.y));
    float sun = pow(max(dot(dir, normalize(vec3(-0.6, 0.5, 0.6))), 0.0), 200.0);
    return color + sun * vec3(1.0, 0.9, 0.7);
}

void main() {
    vec3 surfaceColor = vec3(0.22, 0.22, 0.24);
    vec3 normal = normalize(vNormal);
    vec3 lightDir = normalize(lightPosition - vPosition);
    vec3 viewDir = normalize(u_cameraPosition - vPosition);

    // The matte shading from the previous challenge
    float diff = max(dot(normal, lightDir), 0.0);
    vec3 base = (0.45 + diff) * lightColor * surfaceColor;

    // Reflectance when looking straight at the surface (about 4% for most non-metals)
    float F0 = 0.04;

    // TODO 1: Reflect the ray from the camera around the normal.
    // reflect() expects the incoming direction, which points towards the surface.
    vec3 reflectDir = reflect(-viewDir, normal);

    // TODO 2: Look up the color arriving from that direction with skyColor()
    vec3 reflection = skyColor(reflectDir);

    // TODO 3: Compute cosTheta, the clamped cosine of the angle between normal and viewDir
    float cosTheta = max(dot(normal, viewDir), 0.0);

    // TODO 4: Compute Schlick's approximation using F0 and cosTheta
    float fresnel = F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);

    // TODO 5: Blend base and reflection using fresnel
    vec3 result = mix(base, reflection, fresnel);
    fragColor = vec4(result, 1.0);
}
