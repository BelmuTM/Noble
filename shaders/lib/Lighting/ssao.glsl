/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#define SSAO_SAMPLES 16 // [4 8 16 32 64 128]
#define RADIUS 1.0f
#define BIAS 0.5225f
#define SCALE 3.65f

vec3 hash33(vec3 pos) {
	  pos = vec3(dot(pos, vec3(127.1f, 311.7f, 74.7f)),
			    		dot(pos, vec3(269.5f, 183.3f, 246.1f)),
			    		dot(pos, vec3(113.5f, 271.9f, 124.6f)));

	  return fract(sin(pos) * 43758.5453123f);
}
/*
		Thanks n_r4h33m#7259 for helping
		me with hemisphere sampling!
*/

// Their function
vec3 hemisphereSample(float u, float v) {
     float phi = v * 2.0f * PI;
     float cosTheta = 1.0f - u;
     float sinTheta = sqrt(1.0f - cosTheta * cosTheta);
     return vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
 }

vec3 computeSSAO(vec3 viewPos, vec3 normal) {

    float occlusion = 0.0f;
		for(int i = 0; i <= SSAO_SAMPLES; i++) {
				vec3 noise = hash33(vec3(TexCoords, i));
				vec3 rayDirection = hemisphereSample(noise.x, noise.y);

			  // Fixing wall bug
				if(dot(rayDirection, normal) < 0.0f) rayDirection = -rayDirection;

				vec3 samplePos = viewPos + rayDirection * RADIUS;
        vec2 sampleScreen = viewToScreen(samplePos).xy;
				float sampleDepth = linearizeDepth(texture2D(depthtex0, sampleScreen).r);

				float delta = sampleDepth + samplePos.z;
	      if(delta > 0.0f && delta <= RADIUS) occlusion += delta + BIAS;
		}
		occlusion = 1.0f - (occlusion / SSAO_SAMPLES);
    occlusion = pow(occlusion, SCALE);

	  return vec3(occlusion);
}
