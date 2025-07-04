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
    
        layout (location = 0) out vec3 reflections;

        in vec2 textureCoords;
        in vec2 vertexCoords;

        in vec3 directIlluminance;
        in vec3 skyIlluminance;

        #include "/include/common.glsl"

        #include "/include/utility/rng.glsl"

        #include "/include/atmospherics/constants.glsl"

        #include "/include/utility/phase.glsl"

        #include "/include/fragment/brdf.glsl"
    
        #include "/include/atmospherics/celestial.glsl"

        #include "/include/fragment/raytracer.glsl"
        #include "/include/fragment/reflections.glsl"

        void main() {
            vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
	        if (saturate(fragCoords) != fragCoords) { discard; return; }

            bool  dhFragment = false;
            float depth      = texture(depthtex0, vertexCoords).r;

			mat4 projection        = gbufferProjection;
			mat4 projectionInverse = gbufferProjectionInverse;

            #if defined DISTANT_HORIZONS
                if (depth >= 1.0) {
                    dhFragment = true;
                    depth      = texture(dhDepthTex0, vertexCoords).r;
                    
                    projection        = dhProjection;
                    projectionInverse = dhProjectionInverse;
                }
            #endif

            if (depth == 1.0) { discard; return; }

            Material material   = getMaterial(vertexCoords);
            vec3 screenPosition = vec3(textureCoords, depth);
            vec3 viewPosition   = screenToView(screenPosition, projectionInverse, true);

            float rayLength;
                    
            #if REFLECTIONS == 1
                reflections = computeRoughReflections(dhFragment, projection, viewPosition, material, rayLength);
            #elif REFLECTIONS == 2
                reflections = computeSmoothReflections(dhFragment, projection, viewPosition, material, rayLength);
            #endif

            float reprojectionDepth;
            if (rayLength < EPS) {
                reprojectionDepth = texture(CLOUDMAP_BUFFER, textureCoords).a;
            } else {
                reprojectionDepth = depth + (material.roughness > 0.1 ? 0.0 : rayLength);
            }

            vec3 velocity     = getVelocity(vec3(textureCoords, reprojectionDepth), projectionInverse);
            vec3 prevPosition = vec3(vertexCoords, reprojectionDepth) + velocity;

            vec3 prevReflections = texture(REFLECTIONS_BUFFER, prevPosition.xy).rgb;

            float weight = 0.97;

            vec2 pixelCenterDist = 1.0 - abs(2.0 * fract(prevPosition.xy * viewSize) - 1.0);
            float centerWeight   = sqrt(pixelCenterDist.x * pixelCenterDist.y) * 1.2 - 0.4;

            float velocityWeight = 1.0 - (saturate(length(velocity.xy * viewSize)) * 0.5 + 0.5);

            weight *= centerWeight * velocityWeight;
            weight  = saturate(weight);
            weight *= float(saturate(prevPosition.xy) == prevPosition.xy);

            reflections = max0(mix(reflections, prevReflections, weight));
        }
        
    #endif
#endif
