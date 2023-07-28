/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

void binarySearch(sampler2D depthTexture, inout vec3 rayPosition, vec3 rayDirection, float scale) {
    for(int i = 0; i < BINARY_COUNT; i++) {
        rayPosition  += sign(texelFetch(depthTexture, ivec2(rayPosition.xy * viewSize * scale), 0).r - rayPosition.z) * rayDirection;
        rayDirection *= 0.5;
    }
}

bool raytrace(sampler2D depthTexture, vec3 viewPosition, vec3 rayDirection, int stepCount, float jitter, float scale, out vec3 rayPosition) {
    if(rayDirection.z > -viewPosition.z) return false;

    rayPosition   = viewToScreen(viewPosition);
    rayDirection  = normalize(viewToScreen(viewPosition + rayDirection) - rayPosition);
    rayDirection *= minOf((sign(rayDirection) - rayPosition) / rayDirection) * rcp(stepCount);
    rayPosition  += rayDirection * jitter;

    float depthLenience = max(abs(rayDirection.z) * 3.0, 0.02 / pow2(viewPosition.z)); // Provided by DrDesten

    bool intersect = false;

    for(int i = 0; i < stepCount && !intersect; i++) {
        if(saturate(rayPosition.xy) != rayPosition.xy) return false;

        float depth = texelFetch(depthTexture, ivec2(rayPosition.xy * viewSize * scale), 0).r;
        intersect   = abs(depthLenience - (rayPosition.z - depth)) < depthLenience && depth >= MC_HAND_DEPTH;

        rayPosition += rayDirection;
    }

    #if BINARY_REFINEMENT == 1
        if(intersect) binarySearch(depthTexture, rayPosition, rayDirection, scale);
    #endif

    return intersect;
}

/*
float getMinimumDepthFromLod(vec2 coords, int lod) {
    if(lod == 0) return find2x2MinimumDepth(coords, 1);
	else         return texelFetch(SHADOWMAP_BUFFER, ivec2(getDepthTile(coords, lod) * viewSize), 0).b;
}

vec2 getCellCount(int level) {
    return viewSize / (level == 0 ? 1.0 : exp2(level));
}

vec2 getCell(vec2 rayPosition, vec2 cellTexelSize) {
    return floor(clamp(vec2(0.0), cellTexelSize - vec2(EPS), rayPosition * cellTexelSize));
}

vec3 intersectCellBoundary(vec3 origin, vec3 direction, vec2 cellIndex, vec2 cellCount, vec2 crossStep, vec2 crossOffset)  {
    return origin + direction * minOf(((cellIndex / cellCount + (1.0 / cellCount) * crossStep + crossOffset) - origin.xy) / direction.xy);
}

bool raytraceHiZ(vec3 viewPosition, vec3 rayDirection, int stepCount, float jitter, out vec3 rayPosition) {
    if(rayDirection.z > -viewPosition.z) return false;

    rayPosition  = viewToScreen(viewPosition);
    rayDirection = normalize(viewToScreen(viewPosition + rayDirection) - rayPosition);

    vec3 origin = rayPosition;

    vec2 crossStep   = signNonZero(rayDirection.xy);
    vec2 crossOffset = saturate(crossStep * 1e-5);

    int level = HIZ_START_LOD;

    vec2 cellCount = getCellCount(level);
    vec2 cellIndex = getCell(rayPosition.xy, cellCount);
    rayPosition    = intersectCellBoundary(origin, rayDirection, cellIndex, cellCount, crossStep, crossOffset);

    for(int i = 0; i < stepCount; i++) {
        if(saturate(rayPosition.xy) != rayPosition.xy) return false;

        vec2 currentCellCount = getCellCount(level);
        vec2 oldCellIndex     = getCell(rayPosition.xy, currentCellCount);

        float minLodDepth = getMinimumDepthFromLod(rayPosition.xy, level);

        vec3 tmpRay = origin + (rayDirection / rayDirection.z) * max(rayPosition.z, minLodDepth);

        vec2 newCellIndex = getCell(tmpRay.xy, currentCellCount);

        if(!any(equal(oldCellIndex, newCellIndex))) {
            tmpRay = intersectCellBoundary(origin, rayDirection, oldCellIndex, currentCellCount, crossStep, crossOffset);

            level = min(HIZ_START_LOD, level + 2);
        }

        level--;

        rayPosition = tmpRay;

        if(level < HIZ_STOP_LOD) return true;
    }
    return false;
}
*/
