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

/*
    [References]:
        Wikipedia. (2025). Circle of confusion. https://en.wikipedia.org/wiki/Circle_of_confusion
*/

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#if DOF == 0
    #include "/programs/discard.glsl"
#else
    #if defined STAGE_VERTEX
        #include "/programs/vertex_taau.glsl"

    #elif defined STAGE_FRAGMENT

        /* RENDERTARGETS: 0 */

        layout (location = 0) out vec3 color;

        in vec2 textureCoords;
        in vec2 vertexCoords;

        #include "/include/common.glsl"

        #if TAA == 1
            #include "/include/post/exposure.glsl"
            #include "/include/post/grading.glsl"
        #endif

        #include "/include/post/depth_of_field.glsl"

        void main() {
            bool  modFragment = false;
            float depth       = texture(depthtex0, vertexCoords).r;

            mat4 projectionInverse = gbufferProjectionInverse;

            #if defined CHUNK_LOADER_MOD_ENABLED
                if (depth >= 1.0) {
                    modFragment = true;

                    #if defined VOXY
                        depth = texture(modDepthTex0, textureCoords).r;
                    #else
                        depth = texture(modDepthTex0, vertexCoords).r;
                    #endif

                    projectionInverse = modProjectionInverse;
                }
            #endif

            depth = linearizeDepthFromInverseProjection(depth, projectionInverse);

            #if DOF_DEPTH == 0
                vec2  centerCoords = vec2(RENDER_SCALE * 0.5);
                float centerDepth  = texture(depthtex0, centerCoords).r;

                #if defined CHUNK_LOADER_MOD_ENABLED
                    if (modFragment) {
                        projectionInverse = gbufferProjectionInverse;
                    }
                #endif

                centerDepth = linearizeDepthFromInverseProjection(centerDepth, projectionInverse);

                float targetDepth  = centerDepth;
            #else
                float targetDepth = float(DOF_DEPTH);
            #endif

            depthOfField(color, MAIN_BUFFER, vertexCoords, getCoC(depth, targetDepth));

            color = max0(log2(color + 1.0));
        }
        
    #endif
#endif
