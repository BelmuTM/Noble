/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

vec4 viewToShadow(vec3 viewPos) {
	vec4 worldPos = gbufferModelViewInverse * vec4(viewPos, 1.0f);
	vec4 shadowSpace = shadowProjection * shadowModelView * worldPos;
	shadowSpace.xy = distortPosition(shadowSpace.xy);

	return shadowSpace;
}
