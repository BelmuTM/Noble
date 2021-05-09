/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

vec4 viewToShadow(vec3 viewPos) {
	vec4 worldPos = gbufferModelViewInverse * vec4(viewPos, 1.0f);
	vec4 shadowSpace = shadowProjection * shadowModelView * worldPos;
	shadowSpace.xy = distortPosition(shadowSpace.xy);

	return shadowSpace;
}

vec4 worldToShadow(vec3 worldPos) {
	vec4 shadowSpace = shadowProjection * shadowModelView * vec4(worldPos, 1.0f);
	shadowSpace.xy = distortPosition(shadowSpace.xy);

	return shadowSpace;
}

float visibility(sampler2D shadowMap, vec3 sampleCoords) {
    return step(sampleCoords.z - 0.001f, texture2D(shadowMap, sampleCoords.xy).r);
}

vec3 sampleTransparentShadow(vec3 sampleCoords) {
    float shadowVisibility0 = visibility(shadowtex0, sampleCoords);
    float shadowVisibility1 = visibility(shadowtex1, sampleCoords);
    vec4 shadowColor0 = texture2D(shadowcolor0, sampleCoords.xy);
    vec3 transmittedColor = shadowColor0.rgb * (1.0f - shadowColor0.a);
    return mix((transmittedColor * 1.2f) * shadowVisibility1, vec3(1.0f), shadowVisibility0);
}

#define SHADOW_SAMPLES 3
const int shadowSamplesPerSize = 2 * SHADOW_SAMPLES + 1;
const int totalSamples = shadowSamplesPerSize * shadowSamplesPerSize;

vec3 blurShadows(mat2 rotation, vec3 sampleCoords) {
		vec3 shadowResult = vec3(0.0f);

    for(int x = -SHADOW_SAMPLES; x <= SHADOW_SAMPLES; x++) {
        for(int y = -SHADOW_SAMPLES; y <= SHADOW_SAMPLES; y++) {

            vec2 offset = rotation * vec2(x, y);
            vec3 currentSampleCoordinate = vec3(sampleCoords.xy + offset, sampleCoords.z);
            shadowResult += sampleTransparentShadow(currentSampleCoordinate);
        }
    }
    shadowResult /= totalSamples;
    return shadowResult;
}
