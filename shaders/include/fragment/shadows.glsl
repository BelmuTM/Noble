/***********************************************/
/*       Copyright (C) NobleRT - 2022          */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 worldToShadow(vec3 worldPos) {
	return projOrthoMAD(shadowProjection, transMAD(shadowModelView, worldPos));
}

float contactShadow(vec3 viewPos, vec3 rayDir, int stepCount, float jitter) {
    vec3 rayPos = viewToScreen(viewPos);
         rayDir = normalize(viewToScreen(viewPos + rayDir) - rayPos);

    const float contactShadowDepthLenience = 0.2;

    vec3 increment = rayDir * (contactShadowDepthLenience * (1.0 / stepCount));
         rayPos   += increment * (1.0 + jitter);

    for(int i = 0; i <= stepCount; i++, rayPos += increment) {
        if(clamp01(rayPos.xy) != rayPos.xy) return 1.0;

        float depth = texelFetch(depthtex1, ivec2(rayPos.xy * viewSize), 0).r;
        if(depth >= rayPos.z) return 1.0;

                 depth = linearizeDepth(depth);
        float rayDepth = linearizeDepth(rayPos.z);

        if(abs(depth - rayDepth) / depth < contactShadowDepthLenience) return 0.0;
    }
    return 1.0;
}

float visibility(sampler2D tex, vec3 samplePos) {
    return step(samplePos.z, texelFetch(tex, ivec2(samplePos.xy * shadowMapResolution), 0).r);
}

vec3 getShadowColor(vec3 samplePos) {
    if(clamp01(samplePos) != samplePos) return vec3(1.0);

    float shadow0  = visibility(shadowtex0, samplePos);
    float shadow1  = visibility(shadowtex1, samplePos);
    vec4 shadowCol = texelFetch(shadowcolor0, ivec2(samplePos.xy * shadowMapResolution), 0);

    #if TONEMAP == 0
        shadowCol.rgb = sRGBToAP1Albedo(shadowCol.rgb);
    #else
        shadowCol.rgb = sRGBToLinear(shadowCol.rgb);
    #endif

    shadowCol.rgb *= (1.0 - max0(shadowCol.a));
    return mix(shadowCol.rgb * shadow1, vec3(1.0), shadow0);
}

#if SHADOW_TYPE == 1
    float findBlockerDepth(vec3 shadowPos, float phi) {
        float avgBlockerDepth = 0.0; int BLOCKERS;

        for(int i = 0; i < BLOCKER_SEARCH_SAMPLES; i++) {
            vec2 offset = BLOCKER_SEARCH_RADIUS * diskSampling(i, BLOCKER_SEARCH_SAMPLES, phi * TAU) / shadowMapResolution;
            float z     = texelFetch(shadowtex0, ivec2((shadowPos.xy + offset) * shadowMapResolution), 0).r;

            if(shadowPos.z > z) {
                avgBlockerDepth += z;
                BLOCKERS++;
            }
        }
        return BLOCKERS > 0 ? avgBlockerDepth / BLOCKERS : -1.0;
    }
#endif

vec3 PCF(vec3 shadowPos, float penumbraSize) {
	vec3 shadowResult = vec3(0.0); vec2 offset = vec2(0.0);

    for(int i = 0; i < SHADOW_SAMPLES; i++) {
        #if SHADOW_TYPE != 2
            offset = (diskSampling(i, SHADOW_SAMPLES, randF() * TAU) * penumbraSize) / shadowMapResolution;
        #endif

        vec3 samplePos = distortShadowSpace(shadowPos + vec3(offset, 0.0)) * 0.5 + 0.5;
        shadowResult  += getShadowColor(samplePos);
    }
    return shadowResult / float(SHADOW_SAMPLES);
}

vec3 shadowMap(vec3 viewPos, vec3 geoNormal) {
    #if SHADOWS == 1 
        vec3 shadowPos = worldToShadow(viewToScene(viewPos));
        float NdotL    = dot(geoNormal, sceneShadowDir);

        // Shadow bias from Eldeston#3590 and gri573#7741
        shadowPos += (mat3(shadowProjection) * (mat3(shadowModelView) * geoNormal) * getDistortionFactor(shadowPos.xy)) * 1.01;

        float penumbraSize = 1.0;

        #if SHADOW_TYPE == 0
            penumbraSize = NORMAL_SHADOW_BLUR_RADIUS;

        #elif SHADOW_TYPE == 1
            vec3 shadowPosDistort = distortShadowSpace(shadowPos) * 0.5 + 0.5;
            float avgBlockerDepth = findBlockerDepth(shadowPosDistort, randF());
            if(avgBlockerDepth < 0.0) return vec3(1.0);

            if(texture(shadowcolor0, shadowPosDistort.xy).a >= 0.0)
                penumbraSize = (max0(shadowPosDistort.z - avgBlockerDepth) * LIGHT_SIZE) / avgBlockerDepth;
            else
                penumbraSize = WATER_CAUSTICS_BLUR_RADIUS;
        #endif

        // contactShadow(viewPos, shadowDir, 24, bayer8(gl_FragCoord.xy))
        return PCF(shadowPos, penumbraSize);
    #else
        return vec3(1.0);
    #endif
}
