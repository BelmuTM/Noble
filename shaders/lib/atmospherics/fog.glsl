/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

vec4 Fog(float depth, vec3 viewPos, vec4 fogColorStart, vec4 fogColorEnd, float fogFactor, float density, float opacity) {
    float dist = far;

    if(isEyeInWater == 1) {
        fogFactor = 1.0;
        density = 0.125;
        fogColorStart = vec4(0.0);
        fogColorEnd = vec4(0.345, 0.58, 0.62, 0.65) * density;
    }

    float fogDensity = clamp((-viewPos.z - near) * density, 0.0, pow(far, opacity));
    vec4 fogCol = mix(fogColorStart, fogColorEnd, fogDensity);

    return fogCol * fogFactor;
}
