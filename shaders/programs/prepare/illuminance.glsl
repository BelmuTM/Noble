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

#if defined WORLD_OVERWORLD || defined WORLD_END
    #if defined STAGE_VERTEX
        #include "/settings.glsl"
        #include "/include/taau_scale.glsl"
        
        #include "/include/common.glsl"

        #include "/include/utility/phase.glsl"
        #include "/include/atmospherics/constants.glsl"
        #include "/include/atmospherics/atmosphere.glsl"

        out vec3 directIlluminance;
        out vec3[9] skyIlluminance;

        void main() {
            gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);

            directIlluminance = evaluateDirectIlluminance();
            skyIlluminance    = evaluateUniformSkyIrradiance();
        }

    #elif defined STAGE_FRAGMENT

        /* RENDERTARGETS: 5 */

        layout (location = 0) out vec3 illuminanceOut;

        in vec3 directIlluminance;
        in vec3[9] skyIlluminance;

        void main() {
            illuminanceOut = vec3(0.0);

            if(int(gl_FragCoord.y) == 0) {
                if(int(gl_FragCoord.x) == 0) {
                    illuminanceOut = directIlluminance;
                } else if(int(gl_FragCoord.x) > 0 && int(gl_FragCoord.x) < 10) {
                    illuminanceOut = skyIlluminance[int(gl_FragCoord.x) - 1];
                }
            } else {
                discard;
            }
        }
        
    #endif
#else
    #include "/programs/discard.glsl"
#endif
