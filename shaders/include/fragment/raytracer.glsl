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

vec3 intersectCellBoundary(vec3 origin, vec3 dir, vec2 cellIndex, vec2 cellCount, vec2 crossStep, vec2 crossOffset) {
    vec2 nextCellIndex = cellIndex + crossStep;
    vec2 cellBounds    = (nextCellIndex / cellCount) + crossOffset;

    return origin + dir * minOf((cellBounds - origin.xy) / dir.xy);
}

float getMinimumDepthFromLod(vec2 coords, int lod) {
    if(lod == 0) return find2x2MinimumDepth(coords, 1);
	else         return texelFetch(colortex14, ivec2((coords / exp2(lod) + hiZOffsets[lod - 1]) * viewSize), 0).r;
}

vec2 getCellIndex(vec2 pos, vec2 cellSize) {
    return floor(pos.xy * cellSize);
}

bool hiZTrace(vec3 viewPos, vec3 rayDir, int stepCount, float jitter, inout vec3 ray) {
    if(rayDir.z > -viewPos.z) return false;

    vec3 rayPos = viewToScreen(viewPos);
         rayDir = normalize(viewToScreen(viewPos + rayDir) - rayPos);

    vec3 d = rayDir / rayDir.z;
    vec3 o = rayPos + d * -rayPos.z;

    int level = HIZ_START_LEVEL;

    vec2 crossStep   = signNonZero(d.xy);
    vec2 crossOffset = clamp01(crossStep * pixelSize * exp2(level + 1));

    vec2 startCellSize = floor(viewSize / exp2(level));
    vec2 rayCellIndex  = getCellIndex(rayPos.xy, startCellSize);
         ray           = intersectCellBoundary(o, d, rayCellIndex, startCellSize, crossStep, crossOffset);

    bool intersect = false;

    for(int i = 0; i < stepCount && !intersect; i++) {
        vec2 cellSize     = floor(viewSize / exp2(level));
        vec2 oldCellIndex = getCellIndex(ray.xy, cellSize);

        float minZ  = getMinimumDepthFromLod((oldCellIndex + 0.5) / cellSize, level);
        vec3 tmpRay = o + d * max(ray.z, minZ);

        vec2 newCellIndex = getCellIndex(tmpRay.xy, cellSize);

        if(any(notEqual(oldCellIndex, newCellIndex))) {
            tmpRay = intersectCellBoundary(o, d, oldCellIndex, cellSize, crossStep, crossOffset);
            level++;
        } else level--;

        ray = tmpRay;
        intersect = level < HIZ_STOP_LEVEL && clamp01(ray.xy) == ray.xy;
    }
    return intersect;
}
