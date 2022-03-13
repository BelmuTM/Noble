/***********************************************/
/*       Copyright (C) NobleRT - 2022          */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 worldToShadow(vec3 worldPos) {
	return projMAD(shadowProjection, transMAD(shadowModelView, worldPos));
}

float visibility(sampler2D tex, vec3 samplePos, float bias) {
    return step(samplePos.z - bias, texture(tex, samplePos.xy).r);
}

vec3 getShadowColor(vec3 samplePos, float bias) {
    if(clamp01(samplePos) != samplePos) return vec3(1.0);

    float shadow0  = visibility(shadowtex0, samplePos, bias);
    float shadow1  = visibility(shadowtex1, samplePos, bias);
    vec4 shadowCol = texture(shadowcolor0, samplePos.xy);

    #if TONEMAP == 0
        shadowCol.rgb = sRGBToAP1Albedo(shadowCol.rgb);
    #else
        shadowCol.rgb = sRGBToLinear(shadowCol.rgb);
    #endif

    shadowCol.rgb *= (1.0 - shadowCol.a);
    return mix(shadowCol.rgb * shadow1, vec3(1.0), shadow0);
}

#if SHADOW_TYPE == 1
    float findBlockerDepth(vec3 shadowPos, float bias, float phi) {
        float avgBlockerDepth = 0.0; int BLOCKERS;

        for(int i = 0; i < BLOCKER_SEARCH_SAMPLES; i++) {
            vec2 offset = BLOCKER_SEARCH_RADIUS * diskSampling(i, BLOCKER_SEARCH_SAMPLES, phi * TAU) / shadowMapResolution;
            float z     = texture(shadowtex0, shadowPos.xy + offset).r;

            if(shadowPos.z - bias > z) {
                avgBlockerDepth += z;
                BLOCKERS++;
            }
        }
        return BLOCKERS > 0 ? avgBlockerDepth / BLOCKERS : -1.0;
    }
#endif

vec3 PCF(vec3 shadowPos, float bias, float penumbraSize) {
	vec3 shadowResult = vec3(0.0); vec2 offset = vec2(0.0);

    for(int i = 0; i < SHADOW_SAMPLES; i++) {
        #if SHADOW_TYPE != 2
            offset = (diskSampling(i, SHADOW_SAMPLES, randF() * TAU) * penumbraSize) / shadowMapResolution;
        #endif

        vec3 samplePos = distortShadowSpace(shadowPos + vec3(offset, 0.0)) * 0.5 + 0.5;
        shadowResult  += getShadowColor(samplePos, bias);
    }
    return shadowResult / float(SHADOW_SAMPLES);
}

vec3 shadowMap(vec3 worldPos, vec3 normal) {
    #if SHADOWS == 1 
        vec3 shadowPos = worldToShadow(worldPos);
        float NdotL    = dot(normal, sceneShadowDir);
        if(NdotL < 0.0) return vec3(0.0);

        // Bias method from SixSeven: https://www.curseforge.com/minecraft/customization/voyager-shader-2-0
        // float bias  = (2048.0 / (shadowMapResolution * MC_SHADOW_QUALITY)) + tan(acos(NdotL));
        //      bias *= getDistortionFactor(shadowPos.xy) * 5e-4;

        float bias = 5e-4;
        float penumbraSize = 1.0;

        #if SHADOW_TYPE == 0
            penumbraSize = NORMAL_SHADOW_BLUR_RADIUS;

        #elif SHADOW_TYPE == 1
            vec3 shadowPosDistort = distortShadowSpace(shadowPos) * 0.5 + 0.5;
            float avgBlockerDepth = findBlockerDepth(shadowPosDistort, bias, randF());
            if(avgBlockerDepth < 0.0) return vec3(1.0);

            penumbraSize = (max0(shadowPosDistort.z - avgBlockerDepth) * LIGHT_SIZE) / avgBlockerDepth;
        #endif

        return PCF(shadowPos, bias, penumbraSize);
    #else
        return vec3(1.0);
    #endif
}
