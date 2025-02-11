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

#include "/include/utility/sampling.glsl"

const float bloomScales[6] = float[6](
    0.500000,
    0.250000,
    0.125000,
    0.062500,
    0.031250,
    0.015625
);

const vec2 bloomOffsets[6] = vec2[6](
    vec2(0.0000, 0.0000),
    vec2(0.0000, 0.5010),
    vec2(0.2510, 0.5010),
    vec2(0.2510, 0.6280),
    vec2(0.3145, 0.6280),
    vec2(0.3150, 0.6618)
);

vec3 sampleBloomTile(vec2 coords, int lod) {
    return textureBicubic(SHADOWMAP_BUFFER, coords * bloomScales[lod] + bloomOffsets[lod]).rgb;
}

vec3 computeBloom(vec2 coords) {
    vec3 bloom = vec3(0.0);
    bloom += sampleBloomTile(coords, 0);
    bloom += sampleBloomTile(coords, 1);
    bloom += sampleBloomTile(coords, 2);
    bloom += sampleBloomTile(coords, 3);
    bloom += sampleBloomTile(coords, 4);
    bloom += sampleBloomTile(coords, 5);
    return bloom / 6.0;
}
