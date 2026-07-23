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

#if defined IS_IRIS

    layout (std430, binding = 1) restrict buffer illuminanceBuffer {
        vec3 SSBO_skyIlluminanceCoefficients[9];
        vec3 SSBO_directIlluminance;
        vec3 SSBO_uniformSkyIlluminance;
    };

    #define DIRECT_ILLUMINANCE() \
        SSBO_directIlluminance
    
    #define UNIFORM_SKY_ILLUMINANCE() \
        SSBO_uniformSkyIlluminance

    #define SKY_ILLUMINANCE_COEFFICIENTS() \
        SSBO_skyIlluminanceCoefficients

#else

    vec3[9] sampleUniformSkyIlluminance() {
        return vec3[9](
            texelFetch(ILLUMINANCE_BUFFER, ivec2(0,  2), 0).rgb,
            texelFetch(ILLUMINANCE_BUFFER, ivec2(0,  3), 0).rgb,
            texelFetch(ILLUMINANCE_BUFFER, ivec2(0,  4), 0).rgb,
            texelFetch(ILLUMINANCE_BUFFER, ivec2(0,  5), 0).rgb,
            texelFetch(ILLUMINANCE_BUFFER, ivec2(0,  6), 0).rgb,
            texelFetch(ILLUMINANCE_BUFFER, ivec2(0,  7), 0).rgb,
            texelFetch(ILLUMINANCE_BUFFER, ivec2(0,  8), 0).rgb,
            texelFetch(ILLUMINANCE_BUFFER, ivec2(0,  9), 0).rgb,
            texelFetch(ILLUMINANCE_BUFFER, ivec2(0, 10), 0).rgb
        );
    }
    
    #define DIRECT_ILLUMINANCE() \
        decodeLog(texelFetch(ILLUMINANCE_BUFFER, ivec2(0, 0), 0).rgb)

    #define UNIFORM_SKY_ILLUMINANCE() \
        texelFetch(ILLUMINANCE_BUFFER, ivec2(0, 1), 0).rgb

    #define SKY_ILLUMINANCE_COEFFICIENTS() \
        sampleUniformSkyIlluminance()

#endif
