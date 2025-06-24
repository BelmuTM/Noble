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
        for (int i = 0; i < BINARY_COUNT; i++) {
            rayPosition  += sign(texelFetch(depthTexture, ivec2(rayPosition.xy * viewSize * scale), 0).r - rayPosition.z) * rayDirection;
            rayDirection *= 0.5;
        }
    }
#endif

bool raytrace(sampler2D depthTexture, mat4 projection, vec3 viewPosition, vec3 rayDirection, int stepCount, float jitter, float scale, out vec3 rayPosition) {
    if (rayDirection.z > 0.0 && rayDirection.z >= -viewPosition.z) return false;

    rayPosition   = viewToScreen(viewPosition, projection, true);
    rayDirection  = normalize(viewToScreen(viewPosition + rayDirection, projection, true) - rayPosition);
    rayDirection *= minOf((step(0.0, rayDirection) - rayPosition) / rayDirection) * rcp(stepCount);
    rayPosition  += rayDirection * jitter;

    float depthLenience = max(abs(rayDirection.z) * 3.0, 0.02 / pow2(viewPosition.z)); // Provided by DrDesten

    bool intersect = false;

    for (int i = 0; i < stepCount && !intersect; i++) {
        if (saturate(rayPosition.xy) != rayPosition.xy) return false;

        float depth = texelFetch(depthTexture, ivec2(rayPosition.xy * viewSize * scale), 0).r;
        intersect   = abs(depthLenience - (rayPosition.z - depth)) < depthLenience && depth >= handDepth;

        rayPosition += rayDirection;
    }

    #if defined BINARY_REFINEMENT
        if (intersect) binarySearch(depthTexture, rayPosition, rayDirection, scale);
    #endif

    return intersect;
}

bool raytrace(sampler2D depthTexture, mat4 projection, vec3 viewPosition, vec3 rayDirection, int stepCount, float jitter, float scale, out vec3 rayPosition, out float rayLength) {
    rayLength = 0.0;

    if (rayDirection.z > 0.0 && rayDirection.z >= -viewPosition.z) return false;

    rayPosition   = viewToScreen(viewPosition, projection, true);
    rayDirection  = normalize(viewToScreen(viewPosition + rayDirection, projection, true) - rayPosition);
    rayDirection *= minOf((step(0.0, rayDirection) - rayPosition) / rayDirection) * rcp(stepCount);
    rayPosition  += rayDirection * jitter;

    float initialDepth = rayPosition.z;

    float depthLenience = max(abs(rayDirection.z) * 3.0, 0.02 / pow2(viewPosition.z)); // Provided by DrDesten

    bool intersect = false;

    for (int i = 0; i < stepCount && !intersect; i++) {
        if (saturate(rayPosition.xy) != rayPosition.xy) break;

        float depth = texelFetch(depthTexture, ivec2(rayPosition.xy * viewSize * scale), 0).r;
        intersect   = abs(depthLenience - (rayPosition.z - depth)) < depthLenience && depth >= handDepth;

        rayPosition += rayDirection;
    }

    #if defined BINARY_REFINEMENT
        if (intersect) binarySearch(depthTexture, rayPosition, rayDirection, scale);
    #endif

    if (intersect) {
        rayLength = abs(rayPosition.z - initialDepth);
    }

    return intersect;
}
