/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#define MIN_DISTANCE 5
#define DOF_DISTANCE 120 // [20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200]

#define FOCAL 0.3
#define APERTURE 0.3
#define SIZEMULT 1.0

#define GOLDEN_ANGLE 2.39996323
#define MAX_BLUR_SIZE 20.0
#define RAD_SCALE 1.3

vec3 DOF1(float sceneDepth, vec3 viewPos) {
    float z = sceneDepth * far;
	float coc = min(abs(APERTURE * (FOCAL * (z - centerDepthSmooth)) / (z * (centerDepthSmooth - FOCAL))) * SIZEMULT, (1.0f / viewWidth) * 15.0f);
    float blur = smoothstep(MIN_DISTANCE, DOF_DISTANCE, abs(-viewPos.z - coc));

    if(sceneDepth == 1.0) return texture2D(colortex0, texCoords).rgb;

    vec4 outOfFocusColor = vec4(0.0);
    outOfFocusColor = fastGaussian(colortex0, vec2(viewWidth, viewHeight), 5.65, 15.0, 20.0, outOfFocusColor);
    return mix(texture2D(colortex0, texCoords).rgb, outOfFocusColor.rgb, blur);
}

float getBlurSize(float depth, float focusPoint, float focusScale) {
	float coc = clamp((1.0 / focusPoint - 1.0 / depth) * focusScale, -1.0, 1.0);
	return abs(coc) * MAX_BLUR_SIZE;
}

vec3 DOF2(vec3 color, float sceneDepth, vec3 viewPos) {
    vec3 result = color;
    float focusPoint = 0.8;
    float centerSize = getBlurSize(centerDepthSmooth, focusPoint, FOCAL);
    float tot = 1.0;
    float radius = RAD_SCALE;

    if(isHand(texture2D(depthtex0, texCoords).r) || sceneDepth == 1.0) return texture2D(colortex0, texCoords).rgb;

    float sampleSize;
    for(float ang = 0.0; radius < MAX_BLUR_SIZE; ang += GOLDEN_ANGLE) {
        vec2 tc = texCoords + vec2(cos(ang), sin(ang)) * vec2(1.0 / viewWidth, 1.0 / viewHeight) * radius;
        vec3 sampleColor = texture2D(colortex0, tc).rgb;

        float sampleDepth = texture2D(depthtex0, tc).r * far;
        sampleSize = getBlurSize(sampleDepth, focusPoint, FOCAL);
        if(sampleDepth > centerDepthSmooth) sampleSize = clamp(sampleSize, 0.0, centerSize * 2.0);

        float m = smoothstep(radius - 0.5, radius + 0.5, sampleSize);
        result += mix(result / tot, sampleColor, m);
        tot += 1.0;
        radius += RAD_SCALE / radius;
    }
    float blur = smoothstep(MIN_DISTANCE, DOF_DISTANCE, abs(-viewPos.z - centerSize));
    return mix(color, result /= tot, blur);
}
