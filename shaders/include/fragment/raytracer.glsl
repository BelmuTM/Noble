/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

void binarySearch(inout vec3 rayPos, vec3 rayDir) {
    for(int i = 0; i < BINARY_COUNT; i++) {
        rayPos += sign(texture(depthtex1, rayPos.xy).r - rayPos.z) * rayDir;
        rayDir *= BINARY_DECREASE;
    }
}

bool raytrace(vec3 viewPos, vec3 rayDir, int stepCount, float jitter, inout vec3 rayPos) {
    rayPos  = viewToScreen(viewPos);
    rayDir  = viewToScreen(viewPos + rayDir) - rayPos; 
    rayDir *= minOf3((sign(rayDir) - rayPos) / rayDir) * (1.0 / stepCount); // Taken from the DDA algorithm

    rayPos += rayDir * jitter;
    for(int i = 0; i <= stepCount; i++, rayPos += rayDir) {

        if(clamp01(rayPos.xy) != rayPos.xy) { return false; }
        float depth = texture(depthtex1, rayPos.xy).r;

        if(rayPos.z > depth && abs(RAY_DEPTH_TOLERANCE - (rayPos.z - depth)) < RAY_DEPTH_TOLERANCE) {
            #if BINARY_REFINEMENT == 1
                binarySearch(rayPos, rayDir);
            #endif
            return true;
        }
    }
    return false;
}
