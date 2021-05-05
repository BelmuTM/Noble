/*
  Author: Belmu (https://github.com/BelmuTM/)
  */
#define FOG_SAMPLES 5

vec3 computeVolumetric(vec3 pos) {
    vec3 volumetric = vec3(0.0f);
    
    vec3 rayDir = normalize(pos);
    float increment = length(vec3(0.0f) - pos) / FOG_SAMPLES;
    vec3 currPos = vec3(0.0f);
    float jitter = bayer32(TexCoords);

    for(int i = 0; i < FOG_SAMPLES; i++) {
        vec4 shadowPos = worldToShadow(currPos);
        volumetric += sampleTransparentShadow(shadowPos.xyz * 0.5f + 0.5f).rgb;
        currPos += rayDir * increment;
    }
    volumetric /= FOG_SAMPLES;

    return volumetric;
}
