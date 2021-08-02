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

	for(int i = 0; i < SSAO_SAMPLES; i++) {
		vec2 noise = uniformNoise(i);
		vec3 sampleDir = randomHemisphereDirection(noise.xy) * SSAO_BIAS;
		sampleDir = vec3((tangent * sampleDir.x) + (bitangent * sampleDir.y) + (normal * sampleDir.z));

		vec3 samplePos = sampleOrigin + sampleDir * SSAO_RADIUS;
    		vec2 sampleScreen = viewToScreen(samplePos).xy;
		float sampleDepth = screenToView(vec3(sampleScreen, texture2D(depthtex0, sampleScreen).r)).z;

		float delta = sampleDepth - samplePos.z;
        	if(delta > 0.0 && delta < SSAO_RADIUS) occlusion += delta + SSAO_BIAS;
	}
	occlusion = 1.0 - (occlusion / SSAO_SAMPLES);
	return saturate(occlusion);
}

float computeRTAO(vec3 viewPos, vec3 normal) {
	float occlusion = 1.0;
	vec3 samplePos = viewPos + normal * EPS;

    	vec3 tangent = normalize(cross(gbufferModelView[1].xyz, normal));
    	vec3 bitangent = cross(normal, tangent);

	for(int i = 0; i < RTAO_SAMPLES; i++) {
		vec2 noise = uniformNoise(i);
		vec3 sampleDir = randomHemisphereDirection(noise);
		sampleDir = vec3((tangent * sampleDir.x) + (bitangent * sampleDir.y) + (normal * sampleDir.z));

		vec3 hitPos;
		if(!raytrace(samplePos, sampleDir, RTAO_STEPS, noise.x, hitPos)) continue;

		float dist = distance(samplePos, screenToView(hitPos));
		float attenuation = 1.0 - (dist * dist);
		occlusion += attenuation;
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
		float angle = 0.3;

		vec2 noise = uniformNoise(i);
		vec3 sampleDir = randomHemisphereDirection(noise);
		sampleDir = vec3((tangent * sampleDir.x) + (bitangent * sampleDir.y) + (normal * sampleDir.z));

		float gamma = HALF_PI - ACos(dot(normal, normalize(samplePos - sampleDir)));
		float value = sin(gamma) - sin(angle);
		float attenuation = (1.0 - pow(length(sampleDir) / 3.0, 2.0));

		occlusion += (gamma > angle) ? attenuation * value : 0.0;
		angle = max(angle, gamma * value);
	}
	occlusion /= SSAO_SAMPLES;
	return saturate(occlusion);
}
*/
