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

#if CLOUDS_LAYER0_ENABLED == 0 && CLOUDS_LAYER1_ENABLED == 0 || !defined WORLD_OVERWORLD
    #include "/programs/discard.glsl"
#else
    #include "/include/taau_scale.glsl"

    #if defined STAGE_VERTEX
        #include "/programs/vertex_simple.glsl"

    #elif defined STAGE_FRAGMENT

        #if CLOUDMAP == 1
            /* RENDERTARGETS: 7,14 */

            layout (location = 0) out vec4 clouds;
            layout (location = 1) out vec3 cloudmap;
        #else
            /* RENDERTARGETS: 7 */

            layout (location = 0) out vec4 clouds;
        #endif

        in vec2 textureCoords;

        #include "/include/common.glsl"

        #include "/include/utility/rng.glsl"

        #include "/include/utility/sampling.glsl"
        #include "/include/utility/phase.glsl"
        
        #include "/include/atmospherics/constants.glsl"
        #include "/include/atmospherics/clouds.glsl"

        float find4x4MaximumDepth(sampler2D tex, vec2 coords) {
            coords *= viewSize;

            return maxOf(vec4(
                texelFetch(tex, ivec2(coords) + ivec2( 2,  2), 0).r,
                texelFetch(tex, ivec2(coords) + ivec2(-2,  2), 0).r,
                texelFetch(tex, ivec2(coords) + ivec2(-2, -2), 0).r,
                texelFetch(tex, ivec2(coords) + ivec2( 2, -2), 0).r
            ));
        }

        void main() {
            vec2 vertexCoords = textureCoords * RENDER_SCALE;

            clouds = vec4(0.0, 0.0, 1.0, 0.0);

            bool  modFragment = false;
            float depth       = texture(depthtex0, vertexCoords).r;

            mat4 projectionInverse = gbufferProjectionInverse;

            #if defined CHUNK_LOADER_MOD_ENABLED
                if (depth >= 1.0) {
                    modFragment        = true;
                    projectionInverse = modProjectionInverse;
                }
            #endif

            #if CLOUDMAP == 1
                if (clamp(textureCoords, vec2(0.0), vec2(CLOUDMAP_SCALE)) == textureCoords) {
                    vec3 cloudsCoords   = normalize(unprojectSphere(textureCoords * rcp(CLOUDMAP_SCALE)));
                    vec4 cloudmapLayer0 = estimateCloudsScattering(cloudLayer0, cloudsCoords, false);
                    vec4 cloudmapLayer1 = estimateCloudsScattering(cloudLayer1, cloudsCoords, false);

                    cloudmap.rg  = cloudmapLayer0.rg + cloudmapLayer1.rg * cloudmapLayer0.b;
                    cloudmap.b   = cloudmapLayer0.b  * cloudmapLayer1.b;
                    cloudmap.rgb = max0(cloudmap.rgb);
                }
            #endif

            if (modFragment) {
                if (find4x4MaximumDepth(modDepthTex0, vertexCoords) < 1.0) return;
            } else {
                if (find4x4MaximumDepth(depthtex0, vertexCoords) < 1.0) return;
            }

            vec3 viewPosition       = screenToView(vec3(textureCoords, 1.0), projectionInverse, false);
            vec3 cloudsRayDirection = mat3(gbufferModelViewInverse) * normalize(viewPosition);

            vec4 layer0 = vec4(0.0, 0.0, 1.0, 1e9);
            vec4 layer1 = vec4(0.0, 0.0, 1.0, 1e9);

            #if CLOUDS_LAYER0_ENABLED == 1
                layer0 = estimateCloudsScattering(cloudLayer0, cloudsRayDirection, true);
            #endif

            #if CLOUDS_LAYER1_ENABLED == 1
                layer1 = estimateCloudsScattering(cloudLayer1, cloudsRayDirection, true);
            #endif

            float distanceToClouds = min(layer0.a, layer1.a);

            clouds.rg = layer0.rg + layer1.rg * layer0.b;
            clouds.b  = layer0.b  * layer1.b;

            /* Aerial Perspective */
            float distanceFalloff = quinticStep(0.0, 1.0, sqrt(max0(exp(-5e-5 * distanceToClouds))));

            clouds.rgb = mix(vec3(0.0, 0.0, 1.0), clouds.rgb, distanceFalloff);
            clouds.a   = distanceToClouds;

            /* Reprojection */
            vec2  prevPosition = reproject(viewPosition, distanceToClouds, CLOUDS_WIND_SPEED * frameTime * windDir).xy;
            float prevDepth    = texture(depthtex0, prevPosition.xy).r;

            if (saturate(prevPosition.xy) == prevPosition.xy && prevDepth >= handDepth) {
                vec3 history = max0(textureCatmullRom(CLOUDS_BUFFER, prevPosition.xy).rgb);

                const float centerWeightStrength = 0.6;

                vec2 pixelCenterDist = 1.0 - abs(2.0 * fract(prevPosition.xy * viewSize) - 1.0);
                float centerWeight   = sqrt(pixelCenterDist.x * pixelCenterDist.y) * centerWeightStrength + (1.0 - centerWeightStrength);

                distanceFalloff = quinticStep(0.0, 1.0, sqrt(max0(exp(-5e-4 * distanceToClouds))));
                centerWeight    = mix(0.8, centerWeight, distanceFalloff);
                
                float velocityWeight = saturate(exp(-0.5 * length(cameraPosition - previousCameraPosition)));

                float weight = clamp(centerWeight * velocityWeight, 0.0, 0.97);

                clouds.rgb = max0(mix(clouds.rgb, history, weight));
            }
        }
        
    #endif
#endif
