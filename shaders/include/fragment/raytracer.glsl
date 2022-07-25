/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

void binarySearch(inout vec3 rayPos, vec3 rayDir) {
    for(int i = 0; i < BINARY_COUNT; i++) {
        rayPos += sign(texture(depthtex0, rayPos.xy).r - rayPos.z) * rayDir;
        rayDir *= BINARY_DECREASE;
    }
}

// The favorite raytracer of your favorite raytracer
bool raytrace(vec3 viewPos, vec3 rayDir, int stepCount, float jitter, out vec3 rayPos) {
    // Thanks Bálint#1673 for the clipping fix!
    if(rayDir.z > 0.0 && rayDir.z >= -viewPos.z) return false;

    rayPos  = viewToScreen(viewPos);
    rayDir  = normalize(viewToScreen(viewPos + rayDir) - rayPos);
    rayDir *= minOf((sign(rayDir) - rayPos) / rayDir) * rcp(stepCount); // Taken from the DDA algorithm

    bool intersect = false;

    rayPos += rayDir * jitter;
    for(int i = 0; i <= stepCount && !intersect; i++, rayPos += rayDir) {
        if(clamp01(rayPos.xy) != rayPos.xy) return false;

        float depth         = texelFetch(depthtex0, ivec2(rayPos.xy * viewSize), 0).r;
        float depthLenience = max(abs(rayDir.z) * 3.0, 0.02 / pow2(viewPos.z)); // Provided by DrDesten#6282

        intersect = abs(depthLenience - (rayPos.z - depth)) < depthLenience && depth >= MC_HAND_DEPTH;
    }

    #if BINARY_REFINEMENT == 1
        if(intersect) binarySearch(rayPos, rayDir);
    #endif

    return intersect;
}
