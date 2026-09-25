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

#if defined CHUNK_LOD_MOD_ENABLED

    #if defined STAGE_VERTEX

        out vec2 textureCoords;
        out vec2 vertexCoords;

        void main() {
            gl_Position    = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
            gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w; + (RENDER_SCALE - 1.0);
            textureCoords  = gl_Vertex.xy;
            vertexCoords   = gl_Vertex.xy * RENDER_SCALE;
        }

    #elif defined STAGE_FRAGMENT

        #if defined WRITE_DEPTH_0

            /* RENDERTARGETS: 9 */

            layout (location = 0) out float combinedDepth;

        #elif defined WRITE_DEPTH_1

            /* RENDERTARGETS: 13 */

            layout (location = 0) out float combinedDepth;

        #endif

        in vec2 textureCoords;
        in vec2 vertexCoords;

        #include "/include/uniforms.glsl"
        #include "/include/uniforms_lod_mods.glsl"

        #include "/include/constants.glsl"

        #include "/include/utility/math.glsl"
        #include "/include/utility/transforms.glsl"

        void main() {

            #if defined VOXY
                vec2 modDepthCoords = textureCoords;
            #else
                vec2 modDepthCoords = vertexCoords;
            #endif

            float depth    = texture(depthtex0, vertexCoords).r;
            float depthLod = texture(modDepthTex0, modDepthCoords).r;

            float linearDepth    = screenToViewDepth(depth, gbufferProjectionInverse);
            float linearDepthLod = screenToViewDepth(depthLod, modProjectionInverse);

            combinedDepth = viewToScreenDepth(
                depth < 1.0 ? linearDepth : linearDepthLod,
                combinedProjection
            );

        }
        
    #endif
    
#else

    #include "/programs/discard.glsl"
    
#endif
