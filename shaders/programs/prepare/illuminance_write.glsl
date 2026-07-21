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

#include "/settings.glsl"
#include "/include/taau_scale.glsl"
#include "/include/common.glsl"

const ivec3 workGroups = ivec3(1, 1, 1);

#if defined WORLD_OVERWORLD || defined WORLD_END

    #include "/include/utility/phase.glsl"
    #include "/include/atmospherics/constants.glsl"
    #include "/include/atmospherics/atmosphere.glsl"

    layout (rgba16f) uniform image2D colorimg5;

    layout (local_size_x = 12, local_size_y = 1, local_size_z = 1) in;

    shared vec3 skyIlluminance[9];

    shared vec3 directIlluminance;

    shared vec3 sunTransmittance;
    shared vec3 moonTransmittance;

    void main() {
        uint x = gl_LocalInvocationID.x;

        if (x == 1) {
            evaluateUniformSkyIrradiance(skyIlluminance);

        } else if (x == 0) {
            directIlluminance = evaluateDirectIlluminance(sunTransmittance, moonTransmittance);
        }

        memoryBarrierShared();
        barrier();

        vec3 illuminance = vec3(0.0);

        if (x == 0) {
            // Direct illuminance
            illuminance = encodeLog(directIlluminance);
            
        } else if (x > 0 && x < 10) {
            // Sky illuminance (9 coefficients)
            illuminance = skyIlluminance[x - 1];
            
        } else if (x == 10) {
            // Direct sun transmittance
            illuminance = sunTransmittance;

        } else if (x == 11) {
            // Direct moon transmittance
            illuminance = moonTransmittance;
        }

        imageStore(colorimg5, ivec2(x, 0), vec4(illuminance, 0.0));
    }

#else

    layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

    void main() {
        return;
    }

#endif
