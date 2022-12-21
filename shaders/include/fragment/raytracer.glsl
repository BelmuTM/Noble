/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

void binarySearch(sampler2D depthTexture, inout vec3 rayPos, vec3 rayDir) {
    for(int i = 0; i < BINARY_COUNT; i++) {
        rayPos += sign(texture(depthTexture, rayPos.xy).r - rayPos.z) * rayDir;
        rayDir *= 0.5;
    }
}

bool raytrace(sampler2D depthTexture, vec3 viewPos, vec3 rayDir, int stepCount, float jitter, out vec3 rayPos) {
    if(rayDir.z > -viewPos.z) return false; // Thanks Bálint#1673 for the clipping fix!

    rayPos  = viewToScreen(viewPos);
    rayDir  = normalize(viewToScreen(viewPos + rayDir) - rayPos);
    rayDir *= minOf((sign(rayDir) - rayPos) / rayDir) * rcp(stepCount);
    rayPos += rayDir * jitter;

    bool intersect = false;

    for(int i = 0; i <= stepCount && !intersect; i++, rayPos += rayDir) {
        if(clamp01(rayPos.xy) != rayPos.xy) return false;

        float depth         = texelFetch(depthTexture, ivec2(rayPos.xy * viewSize), 0).r;
        float depthLenience = max(abs(rayDir.z) * 3.0, 0.02 / pow2(viewPos.z)); // Provided by DrDesten#6282

        intersect = abs(depthLenience - (rayPos.z - depth)) < depthLenience && depth >= MC_HAND_DEPTH;
    }

    #if BINARY_REFINEMENT == 1
        if(intersect) binarySearch(depthTexture, rayPos, rayDir);
    #endif

    return intersect;
}
