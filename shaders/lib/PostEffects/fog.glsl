/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#define DENSITY 0.68f
#define OPACITY 0.09f
#define DISTANCE 20.0f

vec4 Fog(float depth, vec4 color, vec3 viewPos, vec4 fogColorStart, vec4 fogColorEnd, float fogFactor) {
    float density = DENSITY;
    float dist = far;

    if(isEyeInWater == 1) {
        fogFactor = 1.0f;
        density = 0.175f;
        fogColorStart = vec4(0.0f);
        fogColorEnd = vec4(0.1f, 0.15f, 0.6f, 1.0f) * density;
    }

    float fogDensity = clamp((-viewPos.z - near) * density, 0.0f, pow(far, OPACITY));
    vec4 fogCol = mix(fogColorStart, fogColorEnd, clamp(-viewPos.z / dist, 0.0f, 1.0f));

    return (fogCol * fogFactor) * fogDensity + color;
}
