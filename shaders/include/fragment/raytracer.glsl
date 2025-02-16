/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2025  Belmu                                                 */
/*                                                                              */
/*    This program is free software: you can redistribute it and/or modify      */
/*    it under the terms of the GNU General Public License as published by      */
/*    the Free Software Foundation, either version 3 of the License, or         */
/*    (at your option) any later version.                                       */
/*                                                                              */
/*    This program is distributed in the hope that it will be useful,           */
/*    but WITHOUT ANY WARRANTY; without even the implied warranty of            */
/*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             */
/*    GNU General Public License for more details.                              */
/*                                                                              */
/*    You should have received a copy of the GNU General Public License         */
/*    along with this program.  If not, see <https://www.gnu.org/licenses/>.    */
/*                                                                              */
/********************************************************************************/

#if defined BINARY_REFINEMENT
    void binarySearch(sampler2D depthTexture, inout vec3 rayPosition, vec3 rayDirection, float scale) {
        for(int i = 0; i < BINARY_COUNT; i++) {
            rayPosition  += sign(texelFetch(depthTexture, ivec2(rayPosition.xy * viewSize * scale), 0).r - rayPosition.z) * rayDirection;
            rayDirection *= 0.5;
        }
    }
#endif

bool raytrace(sampler2D depthTexture, mat4 projection, vec3 viewPosition, vec3 rayDirection, int stepCount, float jitter, float scale, out vec3 rayPosition) {
    if(rayDirection.z > 0.0 && rayDirection.z >= -viewPosition.z) return false;

    rayPosition   = viewToScreen(viewPosition, projection, true);
    rayDirection  = normalize(viewToScreen(viewPosition + rayDirection, projection, true) - rayPosition);
    rayDirection *= minOf((sign(rayDirection) - rayPosition) / rayDirection) * rcp(stepCount);
    rayPosition  += rayDirection * jitter;

    float depthLenience = max(abs(rayDirection.z) * 3.0, 0.02 / pow2(viewPosition.z)); // Provided by DrDesten

    bool intersect = false;

    for(int i = 0; i < stepCount && !intersect; i++) {
        if(saturate(rayPosition.xy) != rayPosition.xy) return false;

        float depth = texelFetch(depthTexture, ivec2(rayPosition.xy * viewSize * scale), 0).r;
        intersect   = abs(depthLenience - (rayPosition.z - depth)) < depthLenience && depth >= handDepth;

        rayPosition += rayDirection;
    }

    #if defined BINARY_REFINEMENT
        if(intersect) binarySearch(depthTexture, rayPosition, rayDirection, scale);
    #endif

    return intersect;
}

bool raytrace(sampler2D depthTexture, mat4 projection, vec3 viewPosition, vec3 rayDirection, int stepCount, float jitter, float scale, out vec3 rayPosition, out float rayLength) {
    rayLength = 0.0;

    if(rayDirection.z > 0.0 && rayDirection.z >= -viewPosition.z) return false;

    rayPosition   = viewToScreen(viewPosition, projection, true);
    rayDirection  = normalize(viewToScreen(viewPosition + rayDirection, projection, true) - rayPosition);
    rayDirection *= minOf((sign(rayDirection) - rayPosition) / rayDirection) * rcp(stepCount);
    rayPosition  += rayDirection * jitter;

    float initialDepth = rayPosition.z;

    float depthLenience = max(abs(rayDirection.z) * 3.0, 0.02 / pow2(viewPosition.z)); // Provided by DrDesten

    bool intersect = false;

    for(int i = 0; i < stepCount && !intersect; i++) {
        if(saturate(rayPosition.xy) != rayPosition.xy) break;

        float depth = texelFetch(depthTexture, ivec2(rayPosition.xy * viewSize * scale), 0).r;
        intersect   = abs(depthLenience - (rayPosition.z - depth)) < depthLenience && depth >= handDepth;

        rayPosition += rayDirection;
    }

    #if defined BINARY_REFINEMENT
        if(intersect) binarySearch(depthTexture, rayPosition, rayDirection, scale);
    #endif

    if(intersect) {
        rayLength = abs(rayPosition.z - initialDepth);
    }

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
