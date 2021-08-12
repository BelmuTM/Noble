/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float computeSSAO(vec3 viewPos, vec3 normal) {
	float occlusion = 1.0;
	vec3 sampleOrigin = viewPos + normal * EPS;

    	vec3 tangent = normalize(cross(gbufferModelView[1].xyz, normal));
    	vec3 bitangent = cross(normal, tangent);

	vec2 noise;
    	#if TAA == 1
     	noise = uniformAnimatedNoise();
    	#endif

	for(int i = 0; i < SSAO_SAMPLES; i++) {
		#if TAA == 0
            	noise = uniformNoise(i);
        	#endif
		vec3 sampleDir = randomHemisphereDirection(noise.xy) * AO_BIAS;
		sampleDir = vec3((tangent * sampleDir.x) + (bitangent * sampleDir.y) + (normal * sampleDir.z));

		vec3 samplePos = sampleOrigin + sampleDir * SSAO_RADIUS;
    		vec2 sampleScreen = viewToScreen(samplePos).xy;
		float sampleDepth = screenToView(vec3(sampleScreen, texture2D(depthtex0, sampleScreen).r)).z;

		float delta = sampleDepth - samplePos.z;
        	if(delta > 0.0 && delta < SSAO_RADIUS) occlusion += delta + AO_BIAS;
	}
	occlusion = 1.0 - (occlusion / SSAO_SAMPLES);
	return saturate(occlusion);
}

float computeRTAO(vec3 viewPos, vec3 normal) {
	float occlusion = 1.0;
	vec3 samplePos = viewPos + normal * EPS;

    	vec3 tangent = normalize(cross(gbufferModelView[1].xyz, normal));
    	vec3 bitangent = cross(normal, tangent);

	vec2 noise;
    	#if TAA == 1
     	noise = uniformAnimatedNoise();
    	#endif

	for(int i = 0; i < RTAO_SAMPLES; i++) {
		#if TAA == 0
            	noise = uniformNoise(i);
        	#endif
		vec3 sampleDir = randomHemisphereDirection(noise) * AO_BIAS;
		sampleDir = vec3((tangent * sampleDir.x) + (bitangent * sampleDir.y) + (normal * sampleDir.z));

		vec3 hitPos;
		if(!raytrace(samplePos, sampleDir, RTAO_STEPS, blueNoise().g, hitPos)) continue;

		float dist = distance(samplePos, screenToView(hitPos));
		float attenuation = 1.0 - (dist * dist);
		occlusion += attenuation + AO_BIAS;
	}
	occlusion = 1.0 - (occlusion / RTAO_SAMPLES);
	return saturate(occlusion);
}

/*
float computeHBAO(vec3 viewPos, vec3 normal) {
	float occlusion = 1.0;
	vec3 samplePos = viewPos + normal * EPS;

    	vec3 tangent = normalize(cross(gbufferModelView[1].xyz, normal));
    	vec3 bitangent = cross(normal, tangent);

	for(int i = 0; i < SSAO_SAMPLES; i++) {
		vec2 noise = uniformNoise(i);
		vec3 sampleDir = randomHemisphereDirection(noise);
		sampleDir = vec3((tangent * sampleDir.x) + (bitangent * sampleDir.y) + (normal * sampleDir.z));

		float gamma = ATan(tangent.z / length(tangent.xy));

		float value = sin(0.2) - sin(gamma);
		float attenuation = 1.0 - (value * value);

		occlusion += attenuation;
	}
	occlusion /= SSAO_SAMPLES;
	return saturate(occlusion);
}
*/
