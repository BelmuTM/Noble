/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if AO_TYPE == 0

	float computeSSAO(vec3 viewPos, vec3 normal) {
		float occlusion = 1.0;

		for(int i = 0; i < SSAO_SAMPLES; i++) {
			vec3 sampleDir = generateCosineVector(normal, uniformNoise(i, blueNoise));

			vec3 samplePos    = viewPos + sampleDir * SSAO_RADIUS;
			float sampleDepth = getViewPos0(viewToScreen(samplePos).xy).z;

			// https://learnopengl.com/Advanced-Lighting/SSAO
			float rangeCheck = quintic(0.0, 1.0, SSAO_RADIUS / abs(viewPos.z - sampleDepth));
        	occlusion 		+= (sampleDepth >= samplePos.z + EPS ? 1.0 : 0.0) * rangeCheck;
		}
		occlusion = 1.0 - (occlusion / SSAO_SAMPLES);
		return clamp01(pow(occlusion, SSAO_STRENGTH));
	}
#else

	float computeRTAO(vec3 viewPos, vec3 normal) {
		vec3 samplePos  = viewPos + normal * 1e-2;
		float occlusion = 0.0; vec3 hitPos;

		for(int i = 0; i < RTAO_SAMPLES; i++) {
			vec2 noise 	   = TAA == 1 ? uniformAnimatedNoise(vec2(randF(rngState), randF(rngState))) : uniformNoise(i, blueNoise);
			vec3 sampleDir = generateCosineVector(normal, noise);

			if(dot(sampleDir, normal) < 0.0) { sampleDir = -sampleDir; }
			if(!raytrace(samplePos, sampleDir, RTAO_STEPS, randF(rngState), hitPos)) { break; }

			float delta = distance(samplePos, screenToView(hitPos));
			occlusion  += delta;
		}
		return clamp01(1.0 - (occlusion / RTAO_SAMPLES));
	}
#endif
