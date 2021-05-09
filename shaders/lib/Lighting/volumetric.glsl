/*
  Author: Belmu (https://github.com/BelmuTM/)
  */
#define LIGHT_SHAFTS_SAMPLES 64 // [16 32 48 64 80 96 112 128]

float sampleShadowmap(vec3 shadowPos) {
	  return texture2D(shadowtex0, shadowPos.xy).r < shadowPos.z ? 0.0f : 1.0f;
}

float VolumetricFog(vec3 viewPos) {
    float density = 0.0f;
    float invSAMPLES = 1.0f / float(LIGHT_SHAFTS_SAMPLES);

    mat4 svp = shadowProjection * shadowModelView;
	  vec4 startPos = svp * gbufferModelViewInverse * vec4(vec3(0.0f), 1.0f);
	  vec4 endPos = svp * gbufferModelViewInverse * vec4(viewPos, 1.0f);

    vec3 increment = normalize(endPos.xyz - startPos.xyz) * length(endPos.xyz - startPos.xyz) * invSAMPLES;
    float jitter = bayer32(TexCoords);
    
    vec3 rayPos = startPos.xyz + increment * jitter;
    for(int i = 0; i < LIGHT_SHAFTS_SAMPLES; i++) {
        vec3 samplePos = distort(rayPos) * 0.5f + 0.5f;
        density += sampleShadowmap(samplePos);
        rayPos += increment;
    }
    density *= invSAMPLES;
    return density;
}
