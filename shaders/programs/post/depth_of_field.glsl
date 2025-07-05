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

        float getCoC(float fragDepth, float targetDepth) {
            return fragDepth <= handDepth ? 0.0 : abs((FOCAL / F_STOPS) * ((FOCAL * (targetDepth - fragDepth)) / (fragDepth * (targetDepth - FOCAL)))) * 0.5;
        }

        void depthOfField(inout vec3 color, sampler2D tex, vec2 coords, float coc) {
            color = vec3(0.0);

            float weight      = pow2(DOF_SAMPLES);
            float totalWeight = EPS;

            float distFromCenter = distance(coords, vec2(0.5));
            vec2  caOffset       = vec2(distFromCenter) * coc / weight;

            for (float angle = 0.0; angle < TAU; angle += TAU / DOF_ANGLE_SAMPLES) {
                for (int i = 0; i < DOF_SAMPLES; i++) {
                    vec2 sampleCoords = coords + vec2(cos(angle), sin(angle)) * i * coc * texelSize;
                    if (saturate(sampleCoords) != sampleCoords) continue;

                    vec3 sampleColor  = vec3(
                        texture(tex, sampleCoords + caOffset).r,
                        texture(tex, sampleCoords           ).g,
                        texture(tex, sampleCoords - caOffset).b
                    );

                    color       += sampleColor * weight;
                    totalWeight += weight;
                }
            }
            color /= totalWeight;
        }

        void main() {
            bool  dhFragment = false;
            float depth      = texture(depthtex0, vertexCoords).r;

            float nearPlane = near;
            float farPlane  = far;

            #if defined DISTANT_HORIZONS
                if (depth >= 1.0) {
                    dhFragment = true;
                    depth      = texture(dhDepthTex0, vertexCoords).r;

                    nearPlane = dhNearPlane;
                    farPlane  = dhFarPlane;
                }
            #endif

            depth = linearizeDepth(depth, nearPlane, farPlane);

            #if DOF_DEPTH == 0
                vec2  centerCoords = vec2(RENDER_SCALE * 0.5);
                float centerDepth  = dhFragment ? texture(dhDepthTex0, centerCoords).r : texture(depthtex0, centerCoords).r;
                float targetDepth  = linearizeDepth(centerDepth, nearPlane, farPlane);
            #else
                float targetDepth = float(DOF_DEPTH);
            #endif

            depthOfField(color, MAIN_BUFFER, vertexCoords, getCoC(depth, targetDepth));

            #if TAA == 1
                color = color * computeExposure(texelFetch(HISTORY_BUFFER, ivec2(0), 0).a);
                color = reinhard(color);
            #endif
        }
        
    #endif
#endif
