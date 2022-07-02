/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if AO_TYPE == 0
	float computeSSAO(vec3 viewPos, vec3 normal) {
		float occlusion = 0.0;

		for(int i = 0; i < SSAO_SAMPLES; i++) {
			vec3 rayDir = generateCosineVector(normal, uniformNoise(i, blueNoise));

			vec3 rayPos    = viewPos + rayDir * SSAO_RADIUS;
			float rayDepth = getViewPos0(viewToScreen(rayPos).xy).z;

			// https://learnopengl.com/Advanced-Lighting/SSAO
			float rangeCheck = quintic(0.0, 1.0, SSAO_RADIUS / abs(viewPos.z - rayDepth));
        	occlusion 		+= (rayDepth >= rayPos.z + EPS ? 1.0 : 0.0) * rangeCheck;
		}
		occlusion = 1.0 - (occlusion / SSAO_SAMPLES);
		return clamp01(pow(occlusion, SSAO_STRENGTH));
	}
#else
	float computeRTAO(vec3 viewPos, vec3 normal) {
		vec3 rayPos     = viewPos + normal * 1e-2;
		float occlusion = 0.0; vec3 hitPos;

		for(int i = 1; i <= RTAO_SAMPLES; i++) {
			vec2 noise = TAA == 1 ? uniformAnimatedNoise(blueNoise.rg) : uniformNoise(i, blueNoise);

			vec3 rayDir = generateCosineVector(normal, noise);
			if(dot(normal, rayDir) < 0.0) rayDir = -rayDir;

			if(!raytrace(rayPos, rayDir, RTAO_STEPS, randF(), hitPos)) { break; }

			float dist = distance(viewToWorld(rayPos), viewToWorld(getViewPos0(hitPos.xy)));
			occlusion += RTAO_STRENGTH / (dist + 1.0);
		}
		return clamp01(1.0 - (occlusion / RTAO_SAMPLES));
	}
#endif
