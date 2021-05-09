/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#define MIN_DISTANCE 5
#define DOF_DISTANCE 120 // [20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200]

#define FOCAL 0.3f
#define APERTURE 0.3f
#define SIZEMULT 1.0f

#define GOLDEN_ANGLE 2.39996323f
#define MAX_BLUR_SIZE 20.0f
#define RAD_SCALE 1.3f

vec3 DOF1(float sceneDepth, vec3 viewPos) {
    float z = sceneDepth * far;
	float coc = min(abs(APERTURE * (FOCAL * (z - centerDepthSmooth)) / (z * (centerDepthSmooth - FOCAL))) * SIZEMULT, (1.0f / viewWidth) * 15.0f);
    float blur = smoothstep(MIN_DISTANCE, DOF_DISTANCE, abs(-viewPos.z - coc));

    if(sceneDepth == 1.0f) return texture2D(colortex0, TexCoords).rgb;

    vec4 outOfFocusColor = vec4(0.0f);
    outOfFocusColor = fastGaussian(colortex0, vec2(viewWidth, viewHeight), 5.65f, 15.0f, 20.0f, outOfFocusColor);
    return mix(texture2D(colortex0, TexCoords).rgb, outOfFocusColor.rgb, blur);
}

float getBlurSize(float depth, float focusPoint, float focusScale) {
	float coc = clamp((1.0f / focusPoint - 1.0f / depth) * focusScale, -1.0f, 1.0f);
	return abs(coc) * MAX_BLUR_SIZE;
}

vec3 DOF2(vec3 color, float sceneDepth, vec3 viewPos) {
    vec3 result = color;
    float focusPoint = 0.8f;
    float centerSize = getBlurSize(centerDepthSmooth, focusPoint, FOCAL);
    float tot = 1.0f;
    float radius = RAD_SCALE;

    if(isHand(texture2D(depthtex0, TexCoords).r) || sceneDepth == 1.0f) return texture2D(colortex0, TexCoords).rgb;

    float sampleSize;
    for(float ang = 0.0f; radius < MAX_BLUR_SIZE; ang += GOLDEN_ANGLE) {
        vec2 tc = TexCoords + vec2(cos(ang), sin(ang)) * vec2(1.0f / viewWidth, 1.0f / viewHeight) * radius;
        vec3 sampleColor = texture2D(colortex0, tc).rgb;

        float sampleDepth = texture2D(depthtex0, tc).r * far;
        sampleSize = getBlurSize(sampleDepth, focusPoint, FOCAL);
        if(sampleDepth > centerDepthSmooth) sampleSize = clamp(sampleSize, 0.0f, centerSize * 2.0f);

        float m = smoothstep(radius - 0.5f, radius + 0.5f, sampleSize);
        result += mix(result / tot, sampleColor, m);
        tot += 1.0f;
        radius += RAD_SCALE / radius;
    }
    float blur = smoothstep(MIN_DISTANCE, DOF_DISTANCE, abs(-viewPos.z - centerSize));
    return mix(color, result /= tot, blur);
}
