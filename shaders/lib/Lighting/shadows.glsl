/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec4 viewToShadow(vec3 viewPos) {
	vec4 worldPos = gbufferModelViewInverse * vec4(viewPos, 1.0);
	vec4 shadowSpace = shadowProjection * shadowModelView * worldPos;
	shadowSpace.xy = distort3(shadowSpace.xy);
	return shadowSpace;
}

float visibility(sampler2D tex, vec3 sampleCoords) {
    return step(sampleCoords.z - EPS, texture2D(tex, sampleCoords.xy).r);
}

vec3 sampleTransparentShadow(vec3 sampleCoords) {
    float shadowVisibility0 = visibility(shadowtex0, sampleCoords);
    float shadowVisibility1 = visibility(shadowtex1, sampleCoords);
    
    vec4 shadowColor0 = texture2D(shadowcolor0, sampleCoords.xy);
    vec3 transmittedColor = shadowColor0.rgb * (1.0 - shadowColor0.a);
    return mix(shadowVisibility1 * transmittedColor, vec3(1.0), shadowVisibility0);
}

bool shadowIntersect(vec3 viewPos) {
    vec3 hitPos; return raytrace(viewPos, normalize(shadowLightPosition), 16, bayer4(gl_FragCoord.xy), hitPos);
}

float findBlockerDepth(vec3 sampleCoords) {
    float BLOCKERS;
    float avgBlockerDepth = 0.0;

    for(int i = 0; i < BLOCKER_SEARCH_SAMPLES; i++) {
        vec2 offset = (BLOCKER_SEARCH_RADIUS * vogelDisk(i, BLOCKER_SEARCH_SAMPLES)) * pixelSize;
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
        for(int i = 0; i < PCSS_SAMPLES; i++) {
            vec2 offset = (rotation * (radius * vogelDisk(i, PCSS_SAMPLES)));
            vec3 currentSampleCoordinate = vec3(sampleCoords.xy + offset, sampleCoords.z);

            shadowResult += sampleTransparentShadow(currentSampleCoordinate);
            SAMPLES++;
        }
    #endif

    return shadowResult / SAMPLES;
}

vec3 PCSS(vec3 sampleCoords, mat2 rotation) {
    float avgBlockerDepth = findBlockerDepth(sampleCoords);
    if(avgBlockerDepth < 0.0) return vec3(1.0);

    float penumbraSize = (max(sampleCoords.z - avgBlockerDepth, 0.0) / avgBlockerDepth) * LIGHT_SIZE;
    return PCF(sampleCoords, penumbraSize, rotation);
}

vec3 shadowMap(vec3 viewPos, float shadowMapResolution) {
    vec3 sampleCoords = viewToShadow(viewPos).xyz * 0.5 + 0.5;
    float theta = uniformNoise(1).r;

    #if SOFT_SHADOWS == 1
        theta *= PI2; // That's wacky, but it looks better on Soft Shadows :D
    #endif
    
    float cosTheta = cos(theta), sinTheta = sin(theta);
    mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta) / shadowMapResolution;

    #if SOFT_SHADOWS == 0
        //float contactShadow = 1.0 - float(shadowIntersect(viewPos));
        return PCF(sampleCoords, 0.0, rotation);
    #else
        return PCSS(sampleCoords, rotation);
    #endif
}
