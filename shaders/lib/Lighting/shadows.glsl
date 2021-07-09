/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec4 viewToShadow(vec3 viewPos) {
	vec4 worldPos = gbufferModelViewInverse * vec4(viewPos, 1.0);
	vec4 shadowSpace = shadowProjection * shadowModelView * worldPos;
	shadowSpace.xyz = distort(shadowSpace.xyz);
	return shadowSpace;
}

vec4 worldToShadow(vec3 worldPos) {
	vec4 shadowSpace = shadowProjection * shadowModelView * vec4(worldPos, 1.0);
	shadowSpace.xyz = distort(shadowSpace.xyz);
	return shadowSpace;
}

float visibility(sampler2D shadowMap, vec3 sampleCoords) {
    return step(sampleCoords.z - EPS, texture2D(shadowMap, sampleCoords.xy).r);
}

vec3 sampleTransparentShadow(vec3 sampleCoords) {
    float shadowVisibility0 = visibility(shadowtex0, sampleCoords);
    float shadowVisibility1 = visibility(shadowtex1, sampleCoords);
    
    vec4 shadowColor0 = texture2D(shadowcolor0, sampleCoords.xy);
    vec3 transmittedColor = shadowColor0.rgb * (1.0 - shadowColor0.a);
    return mix(transmittedColor * shadowVisibility1, vec3(1.0), shadowVisibility0);
}

float findBlockerDepth(vec3 sampleCoords) {
    float BLOCKERS;
    float avgBlockerDepth = 0.0;
    vec2 resolution = 1.0 / vec2(viewWidth, viewHeight);

    for(int i = 0; i < BLOCKER_SEARCH_SAMPLES; i++) {
        vec2 offset = (BLOCKER_SEARCH_RADIUS * poisson32[i]) * resolution;
        float z = texture2D(shadowtex0, sampleCoords.xy + offset).r;
            
        if(sampleCoords.z - EPS > z) {
            BLOCKERS++;
            avgBlockerDepth += z;
        }
    }
    return BLOCKERS > 0.0 ? avgBlockerDepth / BLOCKERS : -1.0;
}

vec3 PCF(vec3 sampleCoords, float radius, mat2 rotation) {
    int SAMPLES;
	vec3 shadowResult = vec3(0.0);

    #if SOFT_SHADOWS == 0
        for(int x = 0; x < SHADOW_SAMPLES; x++) {
            for(int y = 0; y < SHADOW_SAMPLES; y++) {
                vec2 offset = rotation * vec2(x, y);
                vec3 currentSampleCoordinate = vec3(sampleCoords.xy + offset, sampleCoords.z);

                shadowResult += sampleTransparentShadow(currentSampleCoordinate);
                SAMPLES++;
            }
        }
    #else
        vec2 resolution = 1.0 / vec2(viewWidth, viewHeight);
        for(int i = 0; i < PCSS_SAMPLES; i++) {
            vec2 offset = (radius * poisson32[i]) * resolution;
            vec3 currentSampleCoordinate = vec3(sampleCoords.xy + offset, sampleCoords.z);

            shadowResult += sampleTransparentShadow(currentSampleCoordinate);
            SAMPLES++;
        }
    #endif

    return shadowResult / SAMPLES;
}

vec3 PCSS(vec3 sampleCoords) {
    float avgBlockerDepth = findBlockerDepth(sampleCoords);
    if(avgBlockerDepth < 0.0) return vec3(1.0);

    float penumbraSize = (abs(sampleCoords.z - avgBlockerDepth) / avgBlockerDepth) * LIGHT_SIZE;
    return PCF(sampleCoords, penumbraSize, mat2(0.0));
}

vec3 shadowMap(vec3 viewPos, float shadowMapResolution) {
    vec4 shadowSpace = viewToShadow(viewPos);
    vec3 sampleCoords = shadowSpace.xyz * 0.5 + 0.5;

    #if SOFT_SHADOWS == 0
        float randomAngle = bayer64(gl_FragCoord.xy);
        float cosTheta = cos(randomAngle), sinTheta = sin(randomAngle);
        mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta) / shadowMapResolution;
        
        return PCF(sampleCoords, 0.0, rotation);
    #else
        return PCSS(sampleCoords);
    #endif
}
