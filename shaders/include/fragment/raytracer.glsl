/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float taaNoise = TAA == 1 ? uniformAnimatedNoise(hash23(vec3(gl_FragCoord.xy, frameTimeCounter))).x : hash22(gl_FragCoord.xy).x;

vec3 binarySearch(in vec3 rayPos, vec3 rayDir) {

    for(int i = 0; i < BINARY_COUNT; i++) {
        float depthDelta = texture(depthtex1, rayPos.xy).r - rayPos.z;
        rayPos += sign(depthDelta) * rayDir;
        rayDir *= BINARY_DECREASE;
    }
    return rayPos;
}

bool raytrace(vec3 viewPos, vec3 rayDir, int steps, float jitter, inout vec3 hitPos) {
    vec3 screenPos = viewToScreen(viewPos);
    vec3 screenDir = normalize(viewToScreen(viewPos + rayDir) - screenPos) * (RAY_STEP_LENGTH / steps);

    hitPos = screenPos + screenDir * jitter;
    for(int i = 0; i < steps; i++) {
        if(clamp01(hitPos.xy) != hitPos.xy) { return false; }

        float depth = texture(depthtex1, hitPos.xy).r;
        if(depth >= 1.0) { return false; }

        if(abs(1e-2 - (hitPos.z - depth)) < 1e-2 && !isHand(depth)) {

            #if BINARY_REFINEMENT == 1
                hitPos = binarySearch(hitPos, screenDir);
            #endif
            return true;
        }
        hitPos += screenDir;
    }
    return false;
}
