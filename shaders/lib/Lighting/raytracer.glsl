/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 binarySearch(vec3 rayPos, vec3 rayDir) {

    for(int i = 0; i < BINARY_COUNT; i++) {
        float depth = texture2D(depthtex1, rayPos.xy).r;
        float depthDelta = depth - rayPos.z;

        if(depthDelta > 0.0) rayPos += rayDir;
        else rayPos -= rayDir;
        
        rayDir *= BINARY_DECREASE;
    }
    return rayPos;
}

bool raytrace(vec3 viewPos, vec3 rayDir, int steps, float jitter, inout vec3 hitPos) {
    float invSteps = 2.0 / steps;
    vec3 screenPos = viewToScreen(viewPos);
    vec3 screenDir = normalize(viewToScreen(viewPos + rayDir) - screenPos) * invSteps;

    hitPos = screenPos + screenDir * jitter;
    for(int i = 0; i < steps; i++) {
        hitPos += screenDir;

        if(clamp(hitPos.xy, vec2(0.0), vec2(1.0)) != hitPos.xy) break;
        float depth = texture2D(depthtex1, hitPos.xy).r;

        if(hitPos.z >= depth && hitPos.z - depth < MC_HAND_DEPTH) {
            #if BINARY_REFINEMENT == 1
                hitPos = binarySearch(hitPos, screenDir);
            #endif
            return true;
        }
    }
    return false;
}
