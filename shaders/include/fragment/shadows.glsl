/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

vec3 worldToShadow(vec3 worldPos) {
	return projectOrtho(shadowProjection, transform(shadowModelView, worldPos));
}

/*
float contactShadow(vec3 viewPos, vec3 rayDir, int stepCount, float jitter) {
    vec3 rayPos = viewToScreen(viewPos);
         rayDir = normalize(viewToScreen(viewPos + rayDir) - rayPos);

    const float contactShadowDepthLenience = 0.2;

    vec3 increment = rayDir * (contactShadowDepthLenience * rcp(stepCount));
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
*/

float visibility(sampler2D tex, vec3 samplePos) {
    return step(samplePos.z, texelFetch(tex, ivec2(samplePos.xy * shadowMapResolution), 0).r);
}

vec3 getShadowColor(vec3 samplePos) {
    if(clamp01(samplePos) != samplePos) return vec3(1.0);

    float shadowDepth0 = visibility(shadowtex0, samplePos);
    float shadowDepth1 = visibility(shadowtex1, samplePos);
    vec4 shadowCol     = texelFetch(shadowcolor0, ivec2(samplePos.xy * shadowMapResolution), 0);

    #if TONEMAP == ACES
        shadowCol.rgb = srgbToAP1Albedo(shadowCol.rgb);
    #else
        shadowCol.rgb = srgbToLinear(shadowCol.rgb);
    #endif

    return mix(vec3(shadowDepth0), shadowCol.rgb * (1.0 - shadowCol.a), clamp01(shadowDepth1 - shadowDepth0));
}

#if SHADOWS == 1 
    #if SHADOW_TYPE == 1
        float findBlockerDepth(vec3 shadowPos, float phi, out float ssDepth) {
            float avgBlockerDepth = 0.0, totalSSDepth = 0.0; int blockers = 0;

            for(int i = 0; i < BLOCKER_SEARCH_SAMPLES; i++) {
                vec2 offset      = BLOCKER_SEARCH_RADIUS * diskSampling(i, BLOCKER_SEARCH_SAMPLES, phi * TAU) * rcp(shadowMapResolution);
                vec2 localCoords = shadowPos.xy + offset;
                if(clamp01(localCoords) != localCoords) return -1.0;

                ivec2 shadowCoords = ivec2(localCoords * shadowMapResolution);

                float depth0 = texelFetch(shadowtex0, shadowCoords, 0).r;
                float depth1 = texelFetch(shadowtex1, shadowCoords, 0).r;

                if(shadowPos.z > depth0) {
                    avgBlockerDepth += depth0;
                    totalSSDepth    += max0(shadowPos.z - depth1);
                    blockers++;
                }
            }
            // Subsurface depth calculation from SixthSurge#3922
            // -shadowProjectionInverse[2].z helps us convert the depth to a meters scale
            ssDepth = (totalSSDepth * -shadowProjectionInverse[2].z) / (SHADOW_DEPTH_STRETCH * float(blockers));

            return blockers > 0 ? avgBlockerDepth / float(blockers) : -1.0;
        }
    #endif

    vec3 PCF(vec3 shadowPos, float penumbraSize) {
	    vec3 shadowResult = vec3(0.0); vec2 offset = vec2(0.0);

        for(int i = 0; i < SHADOW_SAMPLES; i++) {
            #if SHADOW_TYPE != 2
                offset = (diskSampling(i, SHADOW_SAMPLES, randF() * TAU) * penumbraSize) * rcp(shadowMapResolution);
            #endif

            vec3 samplePos = distortShadowSpace(shadowPos + vec3(offset, 0.0)) * 0.5 + 0.5;
            shadowResult  += getShadowColor(samplePos);
        }
        return shadowResult * rcp(SHADOW_SAMPLES);
    }
#endif

vec3 shadowMap(vec3 scenePos, vec3 geoNormal, out float ssDepth) {
    #if SHADOWS == 1 
        vec3 shadowPos = worldToShadow(scenePos);
        float NdotL    = dot(geoNormal, shadowLightVector);

        // Shadow bias implementation from Emin#7309 and concept from gri573#7741
        float biasAdjust = log2(max(4.0, shadowDistance - shadowMapResolution * 0.125)) * 0.35;
        shadowPos       += mat3(shadowProjection) * (mat3(shadowModelView) * geoNormal) * getDistortionFactor(shadowPos.xy) * biasAdjust;
        shadowPos       *= 1.0002;

        float penumbraSize = 1.0;
        ssDepth = 0.0;

        #if SHADOW_TYPE == 0
            penumbraSize = NORMAL_SHADOW_BLUR_RADIUS;

        #elif SHADOW_TYPE == 1
            vec3 shadowPosDistort = distortShadowSpace(shadowPos) * 0.5 + 0.5;
            float avgBlockerDepth = findBlockerDepth(shadowPosDistort, randF(), ssDepth);
            if(avgBlockerDepth < 0.0) return vec3(-1.0);

            if(texture(shadowcolor0, shadowPosDistort.xy).a >= 0.0)
                penumbraSize = max(0.1, (max0(shadowPosDistort.z - avgBlockerDepth) * LIGHT_SIZE) / avgBlockerDepth);
            else
                penumbraSize = WATER_CAUSTICS_BLUR_RADIUS;
        #endif

        return PCF(shadowPos, penumbraSize);
    #else
        return vec3(1.0);
    #endif
}
