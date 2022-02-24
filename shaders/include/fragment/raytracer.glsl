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

// The favorite raytracer of your favorite raytracer
bool raytrace(vec3 viewPos, vec3 rayDir, int stepCount, float jitter, inout vec3 rayPos) {
    rayPos  = viewToScreen(viewPos);
    rayDir  = viewToScreen(viewPos + rayDir) - rayPos; 
    rayDir *= minOf3((sign(rayDir) - rayPos) / rayDir) * (1.0 / stepCount); // Taken from the DDA algorithm

    bool intersect = false;

    rayPos += rayDir * jitter;
    for(int i = 0; i <= stepCount && !intersect; i++, rayPos += rayDir) {

        if(clamp01(rayPos.xy) != rayPos.xy) return false;

        float depth    = linearizeDepthFast(texture(depthtex1, rayPos.xy).r);
        float rayDepth = linearizeDepthFast(rayPos.z);

        intersect = rayDepth > depth && abs(RAY_DEPTH_TOLERANCE - (rayDepth - depth)) < RAY_DEPTH_TOLERANCE;
    }

    #if BINARY_REFINEMENT == 1
        binarySearch(rayPos, rayDir);
    #endif

    return intersect;
}
