/*
  Author: Belmu (https://github.com/BelmuTM/)
  */
#define VL_SAMPLES 12

float computeVolumetric(vec3 viewPos) {
    float density = 0.0f;
    float invSAMPLES = 1.0f / float(VL_SAMPLES);

    vec4 startPos = viewToShadow(vec3(0.0f));
    vec4 endPos = viewToShadow(viewPos);

    vec3 increment = normalize(endPos.xyz - startPos.xyz) * length(endPos.xyz - startPos.xyz) * invSAMPLES;
    float jitter = bayer32(TexCoords);
    
    vec3 rayPos = startPos.xyz + increment * jitter;
    for(int i = 0; i < VL_SAMPLES; i++) {
        vec3 shadowPos = worldToShadow(rayPos).xyz * 0.5f + 0.5f;
        density += texture2D(shadowtex0, shadowPos.xy).r;

        rayPos += increment;
    }
    density *= invSAMPLES;
    return density;
}
