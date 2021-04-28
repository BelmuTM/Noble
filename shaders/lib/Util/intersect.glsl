/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#define DELTA_EPS 0.001f
#define BINARY_COUNT 20
#define BINARY_DECREASE 0.2f

#define MARCH_DISTANCE 0.75f
#define MARCH_STEP_SIZE 0.005f
#define MARCH_THRESHOLD -5.0f

vec3 binarySearch(float depth, vec3 rayPos, vec3 rayDir) {

    for(int i = 0; i < BINARY_COUNT; i++) {
        float depthDelta = depth - rayPos.z;
        if(abs(depthDelta) < DELTA_EPS) break;

        if(depthDelta > 0.0f) rayPos += rayDir;
        else rayPos -= rayDir;

        rayDir *= BINARY_DECREASE;
    }
    return rayPos;
}

bool SSRT(vec3 viewPos, vec3 rayDir, out vec3 result) {
    vec3 startPos = viewPos;
    vec3 endPos = startPos + rayDir * ((far - near) * MARCH_DISTANCE);

    for(float currStep = MARCH_STEP_SIZE; currStep <= 1.0f; currStep += MARCH_STEP_SIZE) {
        vec3 currPos = startPos + endPos * currStep;

        vec3 currScreenPos = viewToScreen(currPos);
        if(floor(currScreenPos.xy) != vec2(0.0f)) break;

        float targetDepth = linearizeDepth(texture2D(depthtex0, currScreenPos.xy).r);
        float delta = currPos.z + targetDepth;

        if(delta < MARCH_THRESHOLD) break;
        if(delta <= 0.0f) {
            result = binarySearch(targetDepth, currPos, rayDir);
            return true;
        }
    }
    return false;
}
