/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#define DELTA_EPS 0.001f

#define BINARY_REFINEMENT 0 // [0 1]
#define BINARY_COUNT 1 // [1 2 3 4 5 6]
#define BINARY_DECREASE 0.2f

#define MARCH_DISTANCE 3.0f
#define MARCH_STEP_SIZE 0.0445f
#define MARCH_THRESHOLD -5.0f

vec3 binarySearch(vec3 rayPos, vec3 rayDir) {

    for(int i = 0; i < BINARY_COUNT; i++) {
        float depth = linearizeDepth(texture2D(depthtex0, viewToScreen(rayPos).xy).r);
        float depthDelta = depth - rayPos.z;
        if(abs(depthDelta) < DELTA_EPS) break;

        if(depthDelta > 0.0f) rayPos += rayDir;
        else rayPos -= rayDir;

        rayDir *= BINARY_DECREASE;
    }
    return rayPos;
}

bool rayTraceSSGI(vec3 viewPos, vec3 rayDir, out vec3 result) {
    vec3 startPos = viewPos;
    vec3 endPos = startPos + rayDir * ((far - near) * MARCH_DISTANCE);

    for(float currStep = MARCH_STEP_SIZE; currStep <= 1.0f; currStep += MARCH_STEP_SIZE) {
        vec3 currPos = mix(startPos, endPos, currStep);
        #if BINARY_REFINEMENT == 1
            currPos = binarySearch(currPos, rayDir);
        #endif

        vec3 currScreenPos = viewToScreen(currPos);
        if(floor(currScreenPos.xy) != vec2(0.0f)) break;

        float delta = currScreenPos.z - texture2D(depthtex0, currScreenPos.xy).r;

        if(delta < DELTA_EPS && delta > 0.0f) {
            result = vec3(currScreenPos.xy, 0.0f);
            return true;
        }
    }
    return false;
}

bool rayTraceSSR(vec3 viewPos, vec3 rayDir, out vec3 result) {
    vec3 startPos = viewPos;
    vec3 endPos = startPos + rayDir * ((far - near) * MARCH_DISTANCE);

    for(float currStep = 0.005f; currStep <= 1.0f; currStep += 0.005f) {
        vec3 currPos = startPos + endPos * currStep;
        #if BINARY_REFINEMENT == 1
            currPos = binarySearch(currPos, rayDir);
        #endif

        vec3 currScreenPos = viewToScreen(currPos);
        if(floor(currScreenPos.xy) != vec2(0.0f)) break;

        float targetDepth = linearizeDepth(texture2D(depthtex0, currScreenPos.xy).r);
        float delta = currPos.z + targetDepth;

        if(delta < MARCH_THRESHOLD) break;
        if(delta <= 0.0f) {
            result = vec3(currScreenPos.xy, 0.0f);
            return true;
        }
    }
    return false;
}
