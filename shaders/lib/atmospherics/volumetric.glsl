/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#define VL_SAMPLES 80 // [16 32 48 64 80 96 112 128]
#define VL_DENSITY 0.50
#define VL_BRIGHTNESS 1.00 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

float computeVL(vec3 viewPos) {
    float visibility = 0.0;
    float invSAMPLES = 1.0 / float(VL_SAMPLES);

    mat4 conversion = (shadowProjection * shadowModelView) * gbufferModelViewInverse;
    vec4 startPos = conversion * vec4(vec3(0.0), 1.0);
    vec4 endPos = conversion * vec4(viewPos, 1.0);

    vec3 increment = normalize(endPos.xyz - startPos.xyz) * length(endPos.xyz - startPos.xyz) * invSAMPLES;
    float jitter = bayer64(texCoords);
    
    vec3 rayPos = startPos.xyz + increment * jitter;
    for(int i = 0; i < VL_SAMPLES; i++) {
        vec3 samplePos = distort(rayPos) * 0.5 + 0.5;

        visibility += texture2D(shadowtex0, samplePos.xy).r < samplePos.z ? 0.0 : 1.0;
        rayPos += increment;
    }
    visibility *= invSAMPLES;
    return visibility * VL_DENSITY;
}
