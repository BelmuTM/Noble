/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/common.glsl"
#include "/include/atmospherics/constants.glsl"

#if CLOUDS_LAYER0_ENABLED == 0 && CLOUDS_LAYER1_ENABLED == 0
    #include "/programs/discard.glsl"
#else

    #if defined STAGE_VERTEX

        #include "/include/atmospherics/atmosphere.glsl"

        out vec3 skyIlluminance;
        out vec3 directIlluminance;

        void main() {
            gl_Position   = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
            textureCoords = gl_Vertex.xy;

            skyIlluminance    = evaluateUniformSkyIrradianceApproximation();
            directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;
        }

    #elif defined STAGE_FRAGMENT

        /* RENDERTARGETS: 7 */

        layout (location = 0) out vec4 clouds;

        in vec3 skyIlluminance;
        in vec3 directIlluminance;

        #include "/include/utility/sampling.glsl"

        #include "/include/atmospherics/clouds.glsl"

        void main() {
            clouds = vec4(0.0, 0.0, 0.0, 1.0);

            vec3 viewPosition       = getViewPosition1(textureCoords);
            vec3 cloudsRayDirection = mat3(gbufferModelViewInverse) * normalize(viewPosition);

            vec4 layer0 = vec4(0.0, 0.0, 1.0, 1e6);
            vec4 layer1 = vec4(0.0, 0.0, 1.0, 1e6);

            #if CLOUDS_LAYER0_ENABLED == 1
                layer0 = estimateCloudsScattering(cloudLayer0, cloudsRayDirection);
            #endif

            #if CLOUDS_LAYER1_ENABLED == 1
                layer1 = estimateCloudsScattering(cloudLayer1, cloudsRayDirection);
            #endif

            float distanceToClouds = min(layer0.a, layer1.a);
            if(distanceToClouds > EPS) {

                vec2 scattering = layer1.rg    * layer0.z + layer0.rg;
                clouds.rgb     += scattering.r * directIlluminance;
                clouds.rgb     += scattering.g * skyIlluminance;
                clouds.a        = layer0.b     * layer1.b;

                /* Reprojection */
                vec2 prevPosition = reprojectClouds(viewPosition, distanceToClouds).xy;
                vec4 history      = texture(CLOUDS_BUFFER, prevPosition);

                vec2 pixelCenterDist = 1.0 - abs(2.0 * fract(prevPosition * viewSize) - 1.0);
                float centerWeight   = sqrt(pixelCenterDist.x * pixelCenterDist.y) * 0.2 + 0.8;

                float frameWeight = 1.0 / max(texture(DEFERRED_BUFFER, prevPosition).w, 1.0);

                float weight = centerWeight * frameWeight * float(saturate(prevPosition) == prevPosition);

                clouds = clamp16(mix(clouds, history, saturate(weight)));
            }
        }
    #endif
#endif
