#version 300 es
precision highp float;

uniform sampler2D u_texture;
uniform float u_time;

uniform vec2 u_resolution;

out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution;

    // Control variables
    float scanlineFrequency = 100.0;  // Number of scanlines
    float scanlineIntensity = 0.2;    // Intensity of the darkening effect
    
    // Apply movement to the scanlines
    float ySpeed = 0.2;
    float movingY = uv.y + u_time * ySpeed;
    
    // Calculate scanline effect based on vertical position
    float scanline = sin(movingY * scanlineFrequency) * 0.5 + 0.5;
    
    //TODO: Adjust the intensity of the effect
    scanline = mix(1.0, scanline, scanlineIntensity);

    // Texture color
    vec3 textureColor = texture(u_texture, uv).xyz;
    
    //TODO: Blend scanline and texture together
    fragColor = vec4(textureColor * scanline, 1.0);
}