/***********************************************/
/*          Copyright (C) 2023 Belmu           */
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

        void main() {
            vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
	        if(saturate(fragCoords) != fragCoords) { discard; return; }

            clouds = vec3(0.0, 0.0, 1.0);

            float depth = texture(depthtex0, vertexCoords).r;

            if(depth != 1.0) return;

            vec3 viewPosition       = screenToView(vec3(textureCoords, depth));
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

                clouds.rg = layer1.rg * layer0.b + layer0.rg;
                clouds.b  = layer0.b  * layer1.b;

                /* Reprojection */
                vec2 prevPosition = reproject(viewPosition, distanceToClouds, CLOUDS_WIND_SPEED * frameTime * windDir).xy * RENDER_SCALE;
                vec3 history      = texture(CLOUDS_BUFFER, prevPosition).rgb;

                vec2 pixelCenterDist = 1.0 - abs(2.0 * fract(prevPosition * viewSize) - 1.0);
                float centerWeight   = sqrt(pixelCenterDist.x * pixelCenterDist.y) * 0.2 + 0.8;

                float frameWeight = 1.0 / max(texture(ACCUMULATION_BUFFER, prevPosition).a, 1.0);

                float weight = saturate(centerWeight * frameWeight) * float(clamp(prevPosition, 0.0, RENDER_SCALE - 1e-3) == prevPosition);

                clouds = clamp16(mix(clouds, history, weight));
            }
        }
    #endif
#endif
