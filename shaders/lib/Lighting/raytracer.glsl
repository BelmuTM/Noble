/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#define DELTA_EPS 0.001f

#define BINARY_REFINEMENT 1 // [0 1]
#define BINARY_COUNT 48 // [8 16 32 48 64 80 96]
#define BINARY_DECREASE 0.45f

vec3 binarySearch(vec3 rayPos, vec3 rayDir) {

    for(int i = 0; i < BINARY_COUNT; i++) {
        float depth = linearizeDepth(texture2D(depthtex0, rayPos.xy).r);
        float depthDelta = depth - rayPos.z;
        if(abs(depthDelta) < DELTA_EPS) break;

        if(depthDelta > 0.0f) rayPos += rayDir;
        else rayPos -= rayDir;

        rayDir *= BINARY_DECREASE;
    }
    return rayPos;
}

#define RAYTRACE_STEPS 256

bool raytrace(vec3 viewPos, vec3 rayDir, float dither, inout vec2 hitCoord) {
    float invSteps = 1.0f / RAYTRACE_STEPS;
    vec3 screenPos = viewToScreen(viewPos);
    vec3 screenDir = normalize(viewToScreen(viewPos + rayDir) - screenPos) * invSteps;

    vec3 rayPos = screenPos + screenDir * dither;
    for(int i = 0; i < RAYTRACE_STEPS; i++) {
        rayPos += screenDir;

        if(clamp(rayPos.xy, vec2(0.0), vec2(1.0)) != rayPos.xy) break;
        float depth = texture2D(depthtex0, rayPos.xy).r;

        if(rayPos.z > depth) {
            hitCoord = rayPos.xy;
            #if BINARY_REFINEMENT == 1
                hitCoord = binarySearch(rayPos, screenDir).xy;
            #endif
            return true;
        }
    }
    return false;
}

/*#define MARCH_DISTANCE 3.0f
#define MARCH_STEP_SIZE 0.08f
#define MARCH_THRESHOLD -5.0f

bool oldRaytrace(vec3 viewPos, vec3 rayDir, out vec3 result) {
    vec3 startPos = viewPos;
    vec3 endPos = startPos + rayDir * ((far - near) * MARCH_DISTANCE);

    for(float currStep = MARCH_STEP_SIZE; currStep <= 1.0f; currStep += MARCH_STEP_SIZE) {
        vec3 currPos = mix(startPos, endPos, currStep);
        #if BINARY_REFINEMENT == 1
            currPos = binarySearch(currPos, rayDir);
        #endif

        vec3 currScreenPos = viewToScreen(currPos);
        if(floor(currScreenPos.xy) != vec2(0.0f)) break;

        float delta = currScreenPos.z + texture2D(depthtex0, currScreenPos.xy).r;

        if(delta < DELTA_EPS && delta > 0.0f) {
            result = vec3(currScreenPos.xy, 0.0f);
            return true;
        }
    }
    return false;
}*/