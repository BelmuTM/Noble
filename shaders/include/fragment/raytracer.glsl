/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2026  Belmu                                                 */
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

/*
    [References]:
        McGuire, M., & Mara, M. (2014). Efficient GPU Screen-Space Ray Tracing. https://jcgt.org/published/0003/04/04/paper.pdf
*/

float thickenDepth(float depth, float zThickness, mat4 projection) {
    depth = 1.0 - 2.0 * depth;
    depth = (depth + projection[2].z * zThickness) / (1.0 + zThickness);
    return 0.5 - 0.5 * depth;
}

vec2 getCellCount(int mipLevel) {
    return vec2(ceil(viewSize * exp2(-mipLevel)));
}

vec2 getCellIndex(vec2 position, vec2 cellCount) {
    return vec2(floor(position * cellCount));
}

float intersectCell(vec3 origin, vec3 invDirection, vec2 cellIndex, vec2 cellCount, vec2 crossStep) {
    vec2 boundary = (cellIndex + crossStep) / cellCount;
    vec2 dists    = (boundary - origin.xy) * invDirection.xy;

    return min(dists.x, dists.y);
}

bool raytraceHiZ(
    sampler2D depthTexture,
    mat4 projection,
    mat4 projectionInverse,
    vec3 viewPosition,
    vec3 rayDirection,
    float jitter,
    float scale,
    int stepCount,
    out vec3 rayPosition,
    out float rayLength
) {
    rayLength = 0.0;

    // DDA setup (McGuire & Mara, 2014)
    rayPosition   = viewToScreen(viewPosition, projection, true);
    rayDirection  = viewPosition + abs(viewPosition.z) * rayDirection;
    rayDirection  = viewToScreen(rayDirection, projection, true) - rayPosition;
    rayDirection *= minOf((step(0.0, rayDirection) - rayPosition) / rayDirection);

    vec3 origin       = rayPosition;
    vec3 direction    = rayDirection;
    vec3 invDirection = rcp(direction);

    vec2 crossStep = sign(direction.xy) * texelSize;

    bool isBackwardRay = direction.z > 0.0;

    float minZ   = origin.z;
    float maxZ   = origin.z + direction.z;
    float deltaZ = maxZ - minZ;

    int level = HIZ_LOD_COUNT;

    float t = 0.0;

    vec2 cellCount = getCellCount(level);
    vec2 cellIndex = getCellIndex(origin.xy, cellCount);

    rayPosition += direction * intersectCell(origin, invDirection, cellIndex, cellCount, crossStep);

    bool intersected = false;

    for (uint i = 0; i < stepCount && !intersected; i++) {
        cellCount = getCellCount(level);
        cellIndex = getCellIndex(rayPosition.xy, cellCount);

        ivec2 depthMipCoords = ivec2(cellIndex + depthMipsOffsets[level - 1]);

        float cellMinZ = texelFetch(DEPTH_MIPMAP_BUFFER, depthMipCoords, 0).r;

    }

    if (intersected) {
        rayLength = abs(rayPosition.z - minZ);
    }

    return intersected;
}

bool raytrace(
    sampler2D depthTexture,
    mat4 projection,
    mat4 projectionInverse,
    vec3 viewPosition,
    vec3 rayDirection,
    float stride,
    float jitter,
    float scale,
    out vec3 rayPosition,
    out float rayLength
) {
    // Scale the jitter to the stride in pixel size
    jitter *= stride;

    rayLength = 0.0;

    // DDA setup (McGuire & Mara, 2014)
    rayPosition   = viewToScreen(viewPosition, projection, true);
    rayDirection  = viewPosition + abs(viewPosition.z) * rayDirection;
    rayDirection  = viewToScreen(rayDirection, projection, true) - rayPosition;
    rayDirection *= minOf((step(0.0, rayDirection) - rayPosition) / rayDirection);

    vec2 resolution = viewSize * scale;

    rayPosition.xy  *= resolution;
    rayDirection.xy *= resolution;

    // Normalise the DDA ray step to walk a fixed amount of pixels per step
    rayDirection /= maxOf(abs(rayDirection.xy));

    float initialDepth = rayPosition.z;

    // Upper screen-space bounds are XY = resolution - 1.0 and Z = 1.0
    vec3 startPosition = rayPosition;
    vec3 endPosition   = step(0.0, rayDirection) * vec3(resolution - 1.0, 1.0);

    // Compute the minimal amount of steps to reach an upper bound on any axis
    vec3 stepsToEndPosition    = (endPosition - startPosition) / rayDirection;
    // Extend the upper bound to guarantee full coverage of the far plane
         stepsToEndPosition.z += stride;

    // Clamp to the resolution to avoid marching forever
    float tMax = min(minOf(stepsToEndPosition), maxOf(resolution));
    float t    = jitter;

    /*
        Thicken each depth sample by a factor to prevent false positives during
        intersection checks, this makes each depth sample equivalent to a frustum-shaped voxel
        (McGuire & Mara, 2014)
    */
    float zThickness = max(log2(stride), 1.0) * stride * texelSize.y * projectionInverse[1].y;

    bool intersected = false;

    // March until we reach the edge or intersect something
    while (t < tMax && !intersected) {
        rayPosition = startPosition + rayDirection * t;

        float stepT = (t == jitter ? jitter : stride);
        float maxZ  = rayPosition.z;
        float minZ  = rayPosition.z - stepT * abs(rayDirection.z);

        float depth      = texelFetch(depthTexture, ivec2(rayPosition.xy), 0).r;
        float thickDepth = thickenDepth(depth, zThickness, projection);

        /*
            Intersection check, take account of the depth sample's thickness,
            and avoid player hand fragments
        */
        if (maxZ >= depth && minZ <= thickDepth && depth >= handDepth) {
            intersected = true;
        }

        t += stride;
    }

    if (intersected) {
        rayLength = abs(rayPosition.z - initialDepth);
    }

    rayPosition.xy /= resolution;

    return intersected;
}
