/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#define SCATTERING 0.5f
#define FOG_SAMPLES 5

// Modified Mie scattering
float computeScattering(float VdotL) {
    float result = 1.0f - SCATTERING * SCATTERING;
    return result / (4.0f * PI * pow(1.0f + SCATTERING * SCATTERING - (2.0f * SCATTERING) * VdotL, 1.5f));
}

vec3 computeVolumetric(vec3 viewPos) {
    vec3 volumetric = vec3(0.0f);
    
    vec3 rayDir = normalize(viewPos);
    float increment = (vec3(0.0f) - viewPos) / FOG_SAMPLES;
    vec3 currPos = vec3(0.0f);
    float jitter = Bayer8(TexCoords);

    for(int i = 0; i < FOG_SAMPLES; i++) {
        vec3 shadowPos = viewToShadow(currPos);

        volumetric += computeScattering(dot(normalize(currPos), normalize(sunPosition))) * skyColor;

        currPos += rayDir * increment * jitter;
    }
    volumetric /= FOG_SAMPLES;

    return volumetric;
}
