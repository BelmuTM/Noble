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

#include "/settings.glsl"
#include "/include/taau_scale.glsl"
#include "/include/common.glsl"

#include "/include/utility/phase.glsl"
#include "/include/atmospherics/constants.glsl"
#include "/include/atmospherics/atmosphere.glsl"

layout (rgba32f) uniform image2D colorimg5;

layout (local_size_x = 10, local_size_y = 1) in;

const ivec3 workGroups = ivec3(1, 1, 1);

shared vec3 skyIlluminance[9];

void main() {
    uint x = gl_LocalInvocationID.x;

    if (x == 1) {
        evaluateUniformSkyIrradiance(skyIlluminance);
    }

    memoryBarrierShared();
    barrier();

    vec3 illuminance = vec3(0.0);

    if (x == 0) {
        illuminance = evaluateDirectIlluminance();
    } else if (x > 0 && x < 10) {
        illuminance = skyIlluminance[x - 1];
    }

    imageStore(colorimg5, ivec2(x, 0), vec4(illuminance, 0.0));
}
