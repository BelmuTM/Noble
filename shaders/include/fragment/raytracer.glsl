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
    if(rayDir.z > -viewPos.z) return false;

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

vec3 intersectCellBoundary(vec3 origin, vec3 dir, vec2 cellIdx, vec2 cellCount, vec2 crossStep, vec2 crossOffset) {
    vec2 nextCellIdx = cellIdx + crossStep;
    vec2 cellBounds  = (nextCellIdx / cellCount) + crossOffset;

    return origin + dir * minOf((cellBounds - origin.xy) / dir.xy);
}

float getMinimumDepthFromLod(vec2 coords, int lod) {
    if(lod == 0) return find2x2MinimumDepth(coords, 1);
	return texelFetch(colortex14, ivec2((coords / exp2(lod) + hiZOffsets[lod - 1]) * viewSize), 0).r;
}

vec2 getCellIndex(vec2 pos, vec2 cellSize) {
    return floor(pos.xy * cellSize);
}

bool rayTraceHiZ(vec3 viewPos, vec3 rayDir, int stepCount, inout vec3 ray) {
    if(rayDir.z > -viewPos.z) return false;

    vec3 rayPos = viewToScreen(viewPos);
         rayDir = normalize(viewToScreen(viewPos + rayDir) - rayPos);

    vec2 crossStep   = signNonZero(rayDir.xy);
    vec2 crossOffset = clamp01(crossStep * pixelSize * 128.0);

    const int maxMipLevel = 2;
    const int startLevel = 3, stopLevel = 0;
    vec2 startCellSize = pixelSize * exp2(startLevel);

    vec2 rayCellIdx = getCellIndex(rayPos.xy, startCellSize);
         ray        = intersectCellBoundary(rayPos, rayDir, rayCellIdx, startCellSize, crossStep, crossOffset * 64.0);

    int level = startLevel;
    bool intersect = false;

    for(int i = 0; i <= stepCount && !intersect; i++) {
        vec2 cellSize   = pixelSize * exp2(level);
        vec2 oldCellIdx = getCellIndex(ray.xy, cellSize);

        float minZ  = getMinimumDepthFromLod(ray.xy, level);
        vec3 tmpRay = rayPos + rayDir * max(minZ, rayPos.z);

        vec2 newCellIdx = getCellIndex(tmpRay.xy, cellSize);

        if(oldCellIdx != newCellIdx) {
            tmpRay = intersectCellBoundary(rayPos, rayDir, oldCellIdx, cellSize, crossStep, crossOffset);
            level  = min(maxMipLevel, level + 1);
        } else {
            level--;
        }
        ray = tmpRay;
        intersect = level < stopLevel;
    }
    return intersect;
}
