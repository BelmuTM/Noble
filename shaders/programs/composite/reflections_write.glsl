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

#if REFLECTIONS == 0
    #include "/programs/discard.glsl"
#else
    #include "/include/taau_scale.glsl"

    #if defined STAGE_VERTEX

        out vec2 textureCoords;
        out vec2 vertexCoords;
        
        out vec3 directIlluminance;
        out vec3 skyIlluminance;

        uniform sampler2D colortex5;

        void main() {
            gl_Position    = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
            gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w; + (RENDER_SCALE - 1.0);
            textureCoords  = gl_Vertex.xy;
            vertexCoords   = gl_Vertex.xy * RENDER_SCALE;

            #if defined WORLD_OVERWORLD && CLOUDS_LAYER0_ENABLED == 1 || defined WORLD_OVERWORLD && CLOUDS_LAYER1_ENABLED == 1
                directIlluminance = texelFetch(IRRADIANCE_BUFFER, ivec2(0, 0), 0).rgb;
                skyIlluminance    = texelFetch(IRRADIANCE_BUFFER, ivec2(0, 1), 0).rgb;
            #endif
        }

    #elif defined STAGE_FRAGMENT

        /* RENDERTARGETS: 2 */
    
        layout (location = 0) out vec4 reflections;

        in vec2 textureCoords;
        in vec2 vertexCoords;

        in vec3 directIlluminance;
        in vec3 skyIlluminance;

        #include "/include/common.glsl"

        #include "/include/utility/rng.glsl"

        #include "/include/atmospherics/constants.glsl"

        #include "/include/utility/phase.glsl"
        #include "/include/utility/sampling.glsl"

        #include "/include/fragment/brdf.glsl"

        #include "/include/atmospherics/celestial.glsl"

        #include "/include/fragment/raytracer.glsl"
        #include "/include/fragment/reflections.glsl"

        void main() {
            reflections = vec4(0.0);

            #if DOWNSCALED_RENDERING == 1
                vec2 fragCoords = gl_FragCoord.xy * texelSize;
                if (!insideScreenBounds(fragCoords, RENDER_SCALE)) { discard; return; }
            #endif

            bool  modFragment = false;
            float depth       = texture(depthtex0, vertexCoords).r;

            mat4 projection         = gbufferProjection;
            mat4 projectionInverse  = gbufferProjectionInverse;
            mat4 projectionPrevious = gbufferPreviousProjection;

            float nearPlane = near;
            float farPlane  = far;

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

                    nearPlane = modNearPlane;
                    farPlane  = modFarPlane;
                }
            #endif

            if (depth == 1.0) { discard; return; }

            Material material = getMaterial(vertexCoords);

            if (material.F0 <= EPS) return;

            vec3 screenPosition = vec3(textureCoords, depth);
            vec3 viewPosition   = screenToView(screenPosition, projectionInverse, true);

            float rayLength;
                    
            #if REFLECTIONS == 1
                reflections.rgb = computeRoughReflections(modFragment, projection, projectionInverse, viewPosition, material, rayLength);
            #elif REFLECTIONS == 2
                reflections.rgb = computeSmoothReflections(modFragment, projection, projectionInverse, viewPosition, material, rayLength);
            #endif

            vec3 velocity     = getVelocity(vec3(textureCoords, depth), projectionInverse, projectionPrevious);
            vec3 prevPosition = vec3(vertexCoords, depth);

            float reprojectionDepth;
            bool  isReflectingSky = false;
            if (rayLength < EPS) {
                reprojectionDepth = texture(CLOUDMAP_BUFFER, textureCoords).a;
                isReflectingSky   = true;
            } else {
                reprojectionDepth = depth + (material.roughness > 0.1 ? 0.0 : rayLength);
            }

            vec3 velocityReflected     = getVelocity(vec3(textureCoords, reprojectionDepth), projectionInverse, projectionPrevious);
            vec3 prevPositionReflected = vec3(vertexCoords, reprojectionDepth) + velocityReflected;

            vec4 prevReflections = texture(REFLECTIONS_BUFFER, prevPositionReflected.xy);

            bool isHand = depth < handDepth;

            float weight = isHand ? 0.9 : 0.975;

            float linearDepth     = linearizeDepth(prevPosition.z         , nearPlane, farPlane);
            float linearPrevDepth = linearizeDepth(exp2(prevReflections.a), nearPlane, farPlane);
            float depthWeight     = step(abs(linearDepth - linearPrevDepth) / max(linearDepth, linearPrevDepth), 0.01);

            float velocityWeight = 1.0 - saturate(length(velocity.xy * viewSize)) * (isHand ? 1.0 : (isReflectingSky ? 0.8 : 0.5));

            vec2  pixelCenterDist = 1.0 - abs(fract(prevPosition.xy * viewSize) * 2.0 - 1.0);
            float centerWeight    = isHand ? sqrt(pixelCenterDist.x * pixelCenterDist.y) * 0.3 : 1.0;

            weight *= depthWeight * velocityWeight * centerWeight;
            weight  = saturate(weight);
            weight *= float(insideScreenBounds(prevPositionReflected.xy, RENDER_SCALE));
            weight *= float(!isWater(material.id));

            reflections.rgb = max0(mix(reflections.rgb, prevReflections.rgb, weight));
            reflections.a   = log2(prevPosition.z);
        }
        
    #endif
#endif
