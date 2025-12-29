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

    #include "/settings.glsl"
    #include "/include/taau_scale.glsl"
    
    #include "/include/common.glsl"

    #include "/include/utility/phase.glsl"
    #include "/include/atmospherics/constants.glsl"
    #include "/include/atmospherics/atmosphere.glsl"

    #if defined STAGE_VERTEX

        out vec2 textureCoords;
        out vec3 skyIlluminance;

        void main() {
            gl_Position   = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
            textureCoords = gl_Vertex.xy;

            skyIlluminance = evaluateUniformSkyIrradianceApproximation();
        }

    #elif defined STAGE_FRAGMENT

        /* RENDERTARGETS: 6 */

        layout (location = 0) out vec3 sky;

        in vec2 textureCoords;
        in vec3 skyIlluminance;

        void main() {
            vec3 skyRay = normalize(unprojectSphere(textureCoords));
                 sky    = evaluateAtmosphericScattering(skyRay, skyIlluminance);
        }
        
    #endif
    
#else
    #include "/programs/discard.glsl"
#endif
