/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 worldToShadowClip(vec3 worldPos) {
	vec3 shadowPos = projMAD3(shadowProjection, transMAD3(shadowModelView, worldPos));
	return distortShadowSpace(shadowPos.xyz);
}

float visibility(sampler2D tex, vec3 sampleCoords) {
    return step(sampleCoords.z - SHADOW_BIAS, texture(tex, sampleCoords.xy).r);
}

vec3 sampleShadowColor(vec3 sampleCoords) {
    if(clamp01(sampleCoords) != sampleCoords) return vec3(1.0);
    float shadowVisibility0 = visibility(shadowtex0, sampleCoords);
    float shadowVisibility1 = visibility(shadowtex1, sampleCoords);
    
    vec4 shadowColor0     = texture(shadowcolor0, sampleCoords.xy);
    vec3 transmittedColor = shadowColor0.rgb * (1.0 - shadowColor0.a);
    return mix(transmittedColor * shadowVisibility1, vec3(1.0), shadowVisibility0);
}

#if SOFT_SHADOWS == 0

    vec3 PCF(vec3 sampleCoords, mat2 rotation) {
	    vec3 shadowResult = vec3(0.0); int SAMPLES;

        for(int i = 0; i < SHADOW_SAMPLES; i++) {
            for(int j = 0; j < SHADOW_SAMPLES; j++, SAMPLES++) {

                vec3 currSampleCoords = vec3(sampleCoords.xy + (rotation * vec2(i, j)), sampleCoords.z);
                shadowResult         += sampleShadowColor(currSampleCoords);
            }
        }
        return shadowResult / float(SAMPLES);
    }
#else
    float findBlockerDepth(vec3 sampleCoords, mat2 rotation, float phi) {
        float avgBlockerDepth = 0.0;
        int BLOCKERS = 0;

        for(int i = 0; i < BLOCKER_SEARCH_SAMPLES; i++) {
            vec2 offset = BLOCKER_SEARCH_RADIUS * diskSampling(i, BLOCKER_SEARCH_SAMPLES, phi * TAU) * pixelSize;
            float z     = texture(shadowtex0, sampleCoords.xy + offset).r;

            if(sampleCoords.z - SHADOW_BIAS > z) {
                avgBlockerDepth += z;
                BLOCKERS++;
            }
        }
        return BLOCKERS > 0 ? avgBlockerDepth / BLOCKERS : -1.0;
    }

    vec3 PCSS(vec3 sampleCoords, mat2 rotation, float phi) {
        float avgBlockerDepth = findBlockerDepth(sampleCoords, rotation, phi * TAU);
        if(avgBlockerDepth < 0.0) return vec3(1.0);

        float penumbraSize = (max0(sampleCoords.z - avgBlockerDepth) * LIGHT_SIZE) / avgBlockerDepth;

        vec3 shadowResult = vec3(0.0);
        for(int i = 0; i < PCSS_SAMPLES; i++) {
            vec2 offset           = rotation * (penumbraSize * diskSampling(i, PCSS_SAMPLES, phi));
            vec3 currSampleCoords = vec3(sampleCoords.xy + offset, sampleCoords.z);

            shadowResult += sampleShadowColor(currSampleCoords);
        }
        return shadowResult / float(PCSS_SAMPLES);
    }
#endif

vec3 shadowMap(vec3 viewPos) {
    vec3 sampleCoords = 0.5 * worldToShadowClip(transMAD3(gbufferModelViewInverse, viewPos)) + 0.5;
    if(clamp01(sampleCoords) != sampleCoords) return vec3(1.0);
    
    float theta    = (TAA == 1 ? randF() : uniformNoise(1, blueNoise).x);
    float cosTheta = cos(theta), sinTheta = sin(theta);
    mat2 rotation  = mat2(cosTheta, -sinTheta, sinTheta, cosTheta) / shadowMapResolution;

    #if SOFT_SHADOWS == 0
        return PCF(sampleCoords, rotation);
    #else
        return PCSS(sampleCoords, rotation, theta);
    #endif
}
