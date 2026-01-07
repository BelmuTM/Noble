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

#define HIZ_LOD_COUNT 5

const vec2 depthMipsOffsets[] = vec2[](
    vec2(exp2(-0.0)),
    vec2(exp2(-1.0)),
    vec2(exp2(-2.0)),
    vec2(exp2(-3.0))
);

float find2x2MinimumDepth(sampler2D depthTex, vec2 coords, int scale) {
    coords *= viewSize;

    return minOf(vec4(
        texelFetch(depthTex, ivec2(coords)                      , 0).r,
        texelFetch(depthTex, ivec2(coords) + ivec2(1, 0) * scale, 0).r,
        texelFetch(depthTex, ivec2(coords) + ivec2(0, 1) * scale, 0).r,
        texelFetch(depthTex, ivec2(coords) + ivec2(1, 1) * scale, 0).r
    ));
}

float computeDepthMips(sampler2D depthTex, vec2 coords) {
    float tiles = 0.0;

    for (int lod = 1; lod < HIZ_LOD_COUNT; lod++) {
        int scale = int(exp2(lod)); 

        vec2 sampleCoords = (coords - depthMipsOffsets[lod - 1]) * scale;

        tiles += find2x2MinimumDepth(depthTex, sampleCoords, scale);
    }
    return tiles;
}

vec2 getDepthMip(vec2 coords, int lod) {
    return lod == 0 ? coords : clamp(coords, vec2(2e-2), vec2(1.0 - 3e-2)) / int(exp2(lod)) + depthMipsOffsets[lod - 1];
}
