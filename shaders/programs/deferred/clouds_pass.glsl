/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

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

            layout (location = 0) out vec3 clouds;
            layout (location = 1) out vec3 cloudmap;
        #else
            /* RENDERTARGETS: 7 */

            layout (location = 0) out vec3 clouds;
        #endif

        in vec2 textureCoords;

        #include "/include/common.glsl"

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

            clouds = vec3(0.0, 0.0, 1.0);

            sampler2D depthTex = depthtex0;
            float     depth    = texture(depthtex0, vertexCoords).r;

            mat4 projectionInverse = gbufferProjectionInverse;

            #if defined DISTANT_HORIZONS
                if(depth >= 1.0) {
                    depthTex = dhDepthTex0;
                    depth    = texture(dhDepthTex0, vertexCoords).r;

                    projectionInverse = dhProjectionInverse;
                }
            #endif

            #if CLOUDMAP == 1
                if(clamp(textureCoords, vec2(0.0), vec2(CLOUDMAP_SCALE)) == textureCoords) {
                    vec3 cloudsCoords   = normalize(unprojectSphere(textureCoords * rcp(CLOUDMAP_SCALE)));
                    vec4 cloudmapLayer0 = estimateCloudsScattering(cloudLayer0, cloudsCoords, false);
                    vec4 cloudmapLayer1 = estimateCloudsScattering(cloudLayer1, cloudsCoords, false);

                    cloudmap.rg  = cloudmapLayer0.rg + cloudmapLayer1.rg * cloudmapLayer0.b;
                    cloudmap.b   = cloudmapLayer0.b  * cloudmapLayer1.b;
                    cloudmap.rgb = max0(cloudmap.rgb);
                }
            #endif

            if(find4x4MaximumDepth(depthTex, vertexCoords) < 1.0) {
                clouds = texture(CLOUDS_BUFFER, textureCoords).rgb;
                return;
            }

            vec3 viewPosition       = screenToView(vec3(textureCoords, depth), projectionInverse, true);
            vec3 cloudsRayDirection = mat3(gbufferModelViewInverse) * normalize(viewPosition);

            vec4 layer0 = vec4(0.0, 0.0, 1.0, 1e35);
            vec4 layer1 = vec4(0.0, 0.0, 1.0, 1e35);

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
            clouds = mix(vec3(0.0, 0.0, 1.0), clouds, quinticStep(0.0, 1.0, sqrt(max0(exp(-5e-5 * distanceToClouds)))));

            /* Reprojection */
            vec2  prevPosition = reproject(viewPosition, distanceToClouds, CLOUDS_WIND_SPEED * frameTime * windDir).xy;
            float prevDepth    = texture(depthtex0, prevPosition.xy).r;

            if(saturate(prevPosition.xy) == prevPosition.xy && prevDepth >= handDepth) {
                vec3 history = max0(textureCatmullRom(CLOUDS_BUFFER, prevPosition.xy).rgb);

                vec2 pixelCenterDist = 1.0 - abs(2.0 * fract(prevPosition.xy * viewSize) - 1.0);
                float centerWeight   = sqrt(pixelCenterDist.x * pixelCenterDist.y) * 0.1 + 0.9;
                
                float velocityWeight = saturate(length(abs(prevPosition - textureCoords) * viewSize)) * 0.2 + 0.8;
                      velocityWeight = mix(1.0, velocityWeight, float(CLOUDS_SCALE == 100));

                float weight = saturate(centerWeight * velocityWeight);

                clouds = max0(mix(clouds, history, clamp(weight, 0.6, 0.8)));
            }
        }
        
    #endif
#endif
