/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#define DENSITY 0.68
#define OPACITY 0.09
#define DISTANCE 20.0

vec4 Fog(float depth, vec4 color, vec3 viewPos, vec4 fogColorStart, vec4 fogColorEnd, float fogFactor) {
    float density = DENSITY;
    float dist = far;

    if(isEyeInWater == 1) {
        fogFactor = 1.0;
        density = 0.175;
        fogColorStart = vec4(0.0);
        fogColorEnd = vec4(0.1, 0.15, 0.6, 1.0) * density;
    }

    float fogDensity = clamp((-viewPos.z - near) * density, 0.0, pow(far, OPACITY));
    vec4 fogCol = mix(fogColorStart, fogColorEnd, clamp(-viewPos.z / dist, 0.0, 1.0));

    return (fogCol * fogFactor) * fogDensity + color;
}
