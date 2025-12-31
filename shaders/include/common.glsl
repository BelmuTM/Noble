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

#include "/include/constants.glsl"

#include "/include/uniforms.glsl"
#include "/include/uniforms_mods.glsl"

#include "/include/utility/math.glsl"
#include "/include/utility/color.glsl"

#include "/include/utility/transforms.glsl"

#include "/include/utility/material.glsl"

/*
#define HIZ_LOD_COUNT 5

const vec2 hiZOffsets[] = vec2[](
    vec2(0.0, 0.0  ),
    vec2(0.5, 0.0  ),
    vec2(0.5, 0.25 ),
    vec2(0.5, 0.375)
);

float find2x2MinimumDepth(vec2 coords, int scale) {
    coords *= viewSize;

    return minOf(vec4(
        texelFetch(depthtex0, ivec2(coords)                      , 0).r,
        texelFetch(depthtex0, ivec2(coords) + ivec2(1, 0) * scale, 0).r,
        texelFetch(depthtex0, ivec2(coords) + ivec2(0, 1) * scale, 0).r,
        texelFetch(depthtex0, ivec2(coords) + ivec2(1, 1) * scale, 0).r
    ));
}

vec2 getDepthTile(vec2 coords, int lod) {
    return lod == 0 ? coords : coords / exp2(lod) + hiZOffsets[lod - 1];
}

float computeLowerHiZDepthLevels() {
    float tiles = 0.0;

    for (int i = 1; i < HIZ_LOD_COUNT; i++) {
        int scale   = int(exp2(i)); 
        vec2 coords = (textureCoords - hiZOffsets[i - 1]) * scale;
                tiles += find2x2MinimumDepth(coords, scale);
    }
    return tiles;
}
*/
