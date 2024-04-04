/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#include "/include/utility/phase.glsl"
#include "/include/atmospherics/constants.glsl"

#if CLOUDS_LAYER0_ENABLED == 0 && CLOUDS_LAYER1_ENABLED == 0 || !defined WORLD_OVERWORLD
    #include "/programs/discard.glsl"
#else
    #if defined STAGE_VERTEX

        #include "/include/atmospherics/atmosphere.glsl"

        out vec2 textureCoords;
        out vec2 vertexCoords;

        void main() {
            gl_Position    = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
            gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w; + (RENDER_SCALE - 1.0);
            textureCoords  = gl_Vertex.xy;
            vertexCoords   = gl_Vertex.xy * RENDER_SCALE;
        }

    #elif defined STAGE_FRAGMENT

        /* RENDERTARGETS: 7 */

        layout (location = 0) out vec3 clouds;

        in vec2 textureCoords;
        in vec2 vertexCoords;

        #include "/include/utility/sampling.glsl"

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
            vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
	        if(saturate(fragCoords) != fragCoords) { discard; return; }

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

            if(find4x4MaximumDepth(depthTex, vertexCoords) < 1.0) return;

            vec3 viewPosition       = screenToView(vec3(textureCoords, depth), projectionInverse, false);
            vec3 cloudsRayDirection = mat3(gbufferModelViewInverse) * normalize(viewPosition);

            vec4 layer0 = vec4(0.0, 0.0, 1.0, 1e35);
            vec4 layer1 = vec4(0.0, 0.0, 1.0, 1e35);

            #if CLOUDS_LAYER0_ENABLED == 1
                layer0 = estimateCloudsScattering(cloudLayer0, cloudsRayDirection);
            #endif

            #if CLOUDS_LAYER1_ENABLED == 1
                layer1 = estimateCloudsScattering(cloudLayer1, cloudsRayDirection);
            #endif

            float distanceToClouds = min(layer0.a, layer1.a);

            if(distanceToClouds > EPS) {
                clouds.rg = layer0.rg + layer1.rg * layer0.b;
                clouds.b  = layer0.b  * layer1.b;

                /* Reprojection */
                vec2  prevPosition = reproject(viewPosition, distanceToClouds, CLOUDS_WIND_SPEED * frameTime * windDir).xy * RENDER_SCALE;
                float prevDepth    = texture(depthtex0, prevPosition.xy).r;

                if(clamp(prevPosition.xy, 0.0, RENDER_SCALE - 1e-2) == prevPosition.xy && prevDepth >= handDepth) {
                    vec3 history = texture(CLOUDS_BUFFER, prevPosition.xy).rgb;

                    vec2 pixelCenterDist = 1.0 - abs(2.0 * fract(prevPosition.xy * viewSize) - 1.0);
                    float centerWeight   = sqrt(pixelCenterDist.x * pixelCenterDist.y) * 0.2 + 0.8;
                    
                    float velocityWeight = saturate(length(abs(prevPosition - vertexCoords) * viewSize)) * 0.8 + 0.2;
                          velocityWeight = mix(1.0, velocityWeight, float(CLOUDS_SCALE == 100));

                    float weight = saturate(centerWeight * velocityWeight);

                    //clouds = max0(mix(clouds, history, weight));
                }
            }
        }
        
    #endif
#endif
