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
    return step(sampleCoords.z - 0.001, texture2D(shadowMap, sampleCoords.xy).r);
}

vec3 sampleTransparentShadow(vec3 sampleCoords) {
    float shadowVisibility0 = visibility(shadowtex0, sampleCoords);
    float shadowVisibility1 = visibility(shadowtex1, sampleCoords);
    vec4 shadowColor0 = texture2D(shadowcolor0, sampleCoords.xy);
    vec3 transmittedColor = shadowColor0.rgb * (1.0 - shadowColor0.a);
    return mix(transmittedColor * shadowVisibility1, vec3(1.0), shadowVisibility0);
}

vec3 blurShadows(vec3 sampleCoords, mat2 rotation) {
	vec3 shadowResult = vec3(0.0);
    const float shadowSamplesPerSize = 2.0 * SHADOW_SAMPLES + 1.0;

    for(int x = 0; x <= SHADOW_SAMPLES; x++) {
        for(int y = 0; y <= SHADOW_SAMPLES; y++) {

            vec2 offset = rotation * vec2(x, y);
            vec3 currentSampleCoordinate = vec3(sampleCoords.xy + offset, sampleCoords.z);
            shadowResult += sampleTransparentShadow(currentSampleCoordinate);
        }
    }
    shadowResult /= (shadowSamplesPerSize * shadowSamplesPerSize);
    return shadowResult;
}

vec3 shadowMap(float shadowMapResolution) {
    vec3 viewPos = getViewPos();
    vec4 shadowSpace = viewToShadow(viewPos);
    vec3 sampleCoords = shadowSpace.xyz * 0.5 + 0.5;

    float randomAngle = bayer64(gl_FragCoord.xy);
    float cosTheta = cos(randomAngle), sinTheta = sin(randomAngle);
    mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta) / shadowMapResolution;
    return blurShadows(sampleCoords, rotation);
}
