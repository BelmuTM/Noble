/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float computeSSAO(vec3 viewPos, vec3 normal) {
	float occlusion = 1.0;
	vec3 sampleOrigin = viewPos + normal * EPS;
	
	for(int i = 0; i <= SSAO_SAMPLES; i++) {
		vec2 noise = vec2(bayer64(gl_FragCoord.xy), bayer64(gl_FragCoord.yx));
		vec3 sampleDir = randomHemisphereDirection(normal, noise.xy) * SSAO_BIAS;

		vec3 samplePos = sampleOrigin + sampleDir * SSAO_RADIUS;
    		vec2 sampleScreen = viewToScreen(samplePos).xy;
		float sampleDepth = screenToView(vec3(sampleScreen, texture2D(depthtex0, sampleScreen).r)).z;

		float delta = sampleDepth - samplePos.z;
        	if(delta > 0.0 && delta < SSAO_RADIUS) occlusion += delta + SSAO_BIAS;
	}
	occlusion = 1.0 - (occlusion / SSAO_SAMPLES);
	return saturate(occlusion);
}
