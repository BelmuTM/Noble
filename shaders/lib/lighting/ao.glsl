/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float computeSSAO(vec3 viewPos, vec3 normal) {
	float occlusion = 1.0;
	vec3 sampleOrigin = viewPos + normal * EPS;
    mat3 TBN = getTBN(normal);

	for(int i = 0; i < SSAO_SAMPLES; i++) {
		vec2 noise = TAA == 1 ? uniformAnimatedNoise() : uniformNoise(i);
		vec3 sampleDir = TBN * (randomHemisphereDirection(noise.xy) * SSAO_BIAS);

		vec3 samplePos = viewPos + sampleDir * SSAO_RADIUS;
		float sampleDepth = getViewPos(viewToScreen(samplePos).xy).z;

		//float rangeCheck = quintic(0.0, 1.0, abs(viewPos.z - sampleDepth));
        occlusion += (samplePos.z <= sampleDepth ? 0.0 : 1.0);
	}
	occlusion /= SSAO_SAMPLES;
	return saturate(pow(occlusion, SSAO_STRENGTH));
}

float computeRTAO(vec3 viewPos, vec3 normal) {
	float occlusion = 1.0;
	vec3 samplePos = viewPos + normal * EPS;

	mat3 TBN = getTBN(normal);
	vec3 hitPos;

	for(int i = 0; i < RTAO_SAMPLES; i++) {
		vec2 noise = TAA == 1 ? uniformAnimatedNoise() : uniformNoise(i);
		vec3 sampleDir = TBN * (randomHemisphereDirection(noise) * RTAO_BIAS);
		if(!raytrace(samplePos, sampleDir, RTAO_STEPS, blueNoise().g, hitPos)) continue;

		float dist = distance(samplePos, getViewPos(hitPos.xy));
		float attenuation = 1.0 - dist;
		occlusion += attenuation + RTAO_BIAS;
	}
	occlusion = 1.0 - (occlusion / RTAO_SAMPLES);
	return saturate(pow(occlusion, SSAO_STRENGTH));
}
