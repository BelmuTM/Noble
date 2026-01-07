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
        LearnOpenGL. (2015). SSAO. https://learnopengl.com/Advanced-Lighting/SSAO
        Jimenez et al. (2016). Practical Real-Time Strategies for Accurate Indirect Occlusion. https://www.activision.com/cdn/research/Practical_Real_Time_Strategies_for_Accurate_Indirect_Occlusion_NEW%20VERSION_COLOR.pdf
        Jimenez et al. (2016). Practical Realtime Strategies for Accurate Indirect Occlusion. https://blog.selfshadow.com/publications/s2016-shading-course/activision/s2016_pbs_activision_occlusion.pdf
*/

#include "/settings.glsl"
#include "/include/internal_settings.glsl"

#include "/include/taau_scale.glsl"

#if AO == 0 || GI == 1

    #include "/programs/discard.glsl"
    
#else

    #if defined STAGE_VERTEX
        #include "/programs/vertex_taau.glsl"

    #elif defined STAGE_FRAGMENT

        /* RENDERTARGETS: 12 */

        layout (location = 0) out vec3 ao;

        in vec2 textureCoords;
        in vec2 vertexCoords;

        #include "/include/common.glsl"

        #include "/include/utility/rng.glsl"
        
        #include "/include/fragment/ambient_occlusion.glsl"

        void main() {
            ao = vec3(0.0, 0.0, 1.0);

            #if DOWNSCALED_RENDERING == 1
                vec2 fragCoords = gl_FragCoord.xy * texelSize;
                if (!insideScreenBounds(fragCoords, RENDER_SCALE)) { discard; return; }
            #endif
            
            bool  modFragment = false;
            float depth       = texture(depthtex0, vertexCoords).r;

            mat4 projection         = gbufferProjection;
            mat4 projectionInverse  = gbufferProjectionInverse;
            mat4 projectionPrevious = gbufferPreviousProjection;

            #if defined CHUNK_LOADER_MOD_ENABLED
                if (depth >= 1.0) {
                    modFragment = true;

                    #if defined VOXY
                        depth = texture(modDepthTex0, textureCoords).r;
                    #else
                        depth = texture(modDepthTex0, vertexCoords).r;
                    #endif
                    
                    projection         = modProjection;
                    projectionInverse  = modProjectionInverse;
                    projectionPrevious = modProjectionPrevious;
                }
            #endif

            if (depth == 1.0) { discard; return; }

            uvec4 dataTexture = texelFetch(GBUFFERS_DATA, ivec2(vertexCoords * viewSize), 0);
            vec3  normal      = mat3(gbufferModelView) * decodeUnitVector(vec2(dataTexture.w & 65535u, dataTexture.w >> 16u & 65535u) * rcpMaxFloat16);

            if (depth < handDepth) {
                ao = vec3(encodeUnitVector(normal), 1.0);
                return;
            }

            vec3 viewPosition = screenToView(vec3(textureCoords, depth), projectionInverse, true);

            viewPosition += normal * 1e-2;

            vec3 bentNormal = vec3(0.0);

            if (modFragment) {
                #if AO == 1
                    ao.b = GTAO(modDepthTex0, projectionInverse, viewPosition, normal, bentNormal);
                #elif AO == 2
                    ao.b = SSAO(modDepthTex0, projection, projectionInverse, viewPosition, normal, bentNormal);
                #elif AO == 3
                    ao.b = RTAO(modDepthTex0, projection, projectionInverse, viewPosition, normal, bentNormal);
                #endif
            } else {
                #if AO == 1
                    ao.b = GTAO(depthtex0, projectionInverse, viewPosition, normal, bentNormal);
                #elif AO == 2
                    ao.b = SSAO(depthtex0, projection, projectionInverse, viewPosition, normal, bentNormal);
                #elif AO == 3
                    ao.b = RTAO(depthtex0, projection, projectionInverse, viewPosition, normal, bentNormal);
                #endif  
            }

            bentNormal = normalize(bentNormal);

            #if AO_FILTER == 1

                vec3 currFragment = vec3(textureCoords, depth);

                vec3 closestFragment;
                if (modFragment) {
                    closestFragment = getClosestFragment(modDepthTex0, currFragment);
                } else {
                    closestFragment = getClosestFragment(depthtex0, currFragment);
                }

                vec2 prevCoords = vertexCoords + getVelocity(closestFragment, projectionInverse, projectionPrevious).xy * RENDER_SCALE;

                if (insideScreenBounds(prevCoords, RENDER_SCALE)) {
                    vec3 prevAO         = texture(AO_BUFFER, prevCoords).rgb;
                    vec3 prevBentNormal = decodeUnitVector(prevAO.xy);
            
                    float weight = saturate(1.0 / max(texture(DEFERRED_BUFFER, prevCoords).a * 0.75, 1.0));

                    ao.xy = encodeUnitVector(mix(prevBentNormal, bentNormal, weight));
                    ao.b  = mix(prevAO.b, ao.b, weight);
                } else {
                    ao = vec3(encodeUnitVector(normal), ao.b);
                }

            #else
                ao.xy = encodeUnitVector(bentNormal);
            #endif

            ao = saturate(ao);
        }
        
    #endif

#endif
    