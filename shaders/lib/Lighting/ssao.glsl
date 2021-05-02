/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#define SSAO_SCALE 1
#define SSAO_SAMPLES 16 // [4 8 16 32 64 128]
#define SSAO_RADIUS 1.5f
#define SSAO_BIAS 0.295f

/*
		Thanks n_r4h33m#7259 for helping
		me with hemisphere sampling!
*/
vec3 computeSSAO(vec3 viewPos, vec3 normal) {
		float occlusion = 1.0f;
		// Avoid affecting hand
		if(isHand(texture2D(depthtex0, TexCoords).r)) return vec3(occlusion);

		vec3 sampleOrigin = viewPos + normal * 0.01f;
		for(int i = 0; i <= SSAO_SAMPLES; i++) {
				vec3 noise = hash33(vec3(TexCoords, i));
				float cosTheta = 0.0f;
				vec3 sampleDir = normalize(hemisphereSample(noise.x, noise.y, cosTheta)) * SSAO_BIAS;

			  // Fixing wall bug
				if(dot(normal, sampleDir) < 0.0f) sampleDir = -sampleDir;

				vec3 samplePos = sampleOrigin + sampleDir * SSAO_RADIUS;
        vec2 sampleScreen = viewToScreen(samplePos).xy;
				float sampleDepth = screenToView(vec3(sampleScreen, texture2D(depthtex0, sampleScreen).r)).z;

				float delta = sampleDepth - samplePos.z;
        if(delta > 0.0f && delta < SSAO_RADIUS) occlusion += delta + SSAO_BIAS;
		}
		occlusion = pow(1.0f - (occlusion / SSAO_SAMPLES), SSAO_SCALE);
	  return vec3(occlusion);
}
