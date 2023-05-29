/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/common.glsl"

#if GI == 1
    /* RENDERTARGETS: 4,9,10,11 */

    layout (location = 0) out vec4 color;
    layout (location = 1) out vec3 direct;
    layout (location = 2) out vec3 indirect;
    layout (location = 3) out vec4 temporalData;
#else
    /* RENDERTARGETS: 4,11 */

    layout (location = 0) out vec4 color;
    layout (location = 1) out vec4 temporalData;
#endif

#include "/include/atmospherics/constants.glsl"

#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/brdf.glsl"

#include "/include/atmospherics/celestial.glsl"

#if GI == 1
    #include "/include/fragment/pathtracer.glsl"
#endif

void main() {
    vec3 viewPosition0 = getViewPosition0(textureCoords);

    #if GI == 1
        vec2 tempCoords = textureCoords * rcp(GI_SCALE);
    #else
        vec2 tempCoords = textureCoords;
    #endif

    if(isSky(textureCoords)) {
        vec3 sky = renderAtmosphere(viewPosition0);
        #if GI == 1
            direct = sky;
        #else
            color.rgb = sky;
        #endif
        return;
    }

    Material material = getMaterial(tempCoords);

    #if HARDCODED_SSS == 1
        if(material.blockId > NETHER_PORTAL_ID && material.blockId <= PLANTS_ID && material.subsurface <= EPS) material.subsurface = HARDCODED_SSS_VAL;
    #endif

    #if AO_FILTER == 1 && GI == 0 || GI == 1
        vec3 currPosition = vec3(textureCoords, material.depth0);
        vec3 prevPosition = currPosition - getVelocity(currPosition);
        vec4 history      = texture(DEFERRED_BUFFER, prevPosition.xy);

        #if RENDER_MODE == 0
            float prevDepth = exp2(texture(MOMENTS_BUFFER, prevPosition.xy).a);
            float weight    = pow(exp(-abs(linearizeDepthFast(material.depth0) - linearizeDepthFast(prevDepth))), TEMPORAL_DEPTH_WEIGHT_SIGMA);

            vec2 pixelCenterDist = 1.0 - abs(2.0 * fract(prevPosition.xy * viewSize) - 1.0);
                 weight         *= sqrt(pixelCenterDist.x * pixelCenterDist.y) * 0.2 + 0.8;

            temporalData.a = log2(material.depth0);
        #else
            float weight = float(hideGUI);
        #endif

        color.a = (history.a * weight * float(saturate(prevPosition.xy) == prevPosition.xy) * float(!isHand(textureCoords))) + 1.0;
    #endif

    #if GI == 0
        color.rgb = vec3(0.0);

        if(material.F0 * maxVal8 <= 229.5) {
            vec3 skyIlluminance = vec3(0.0), directIlluminance = vec3(0.0);
            float cloudsShadows = 1.0; vec4 shadowmap = vec4(1.0, 1.0, 1.0, 0.0);

            #if defined WORLD_OVERWORLD || defined WORLD_END
                directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;

                #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
                    cloudsShadows = getCloudsShadows(viewToScene(viewPosition0));
                #endif

                skyIlluminance = texture(ILLUMINANCE_BUFFER, textureCoords).rgb;

                #if SHADOWS == 1
                    shadowmap = texture(SHADOWMAP_BUFFER, textureCoords);
                #endif
            #endif

            float ao = 1.0;
            #if AO == 1
                ao = texture(INDIRECT_BUFFER, textureCoords).a;
            #endif

            color.rgb = computeDiffuse(viewPosition0, shadowVec, material, shadowmap, directIlluminance, skyIlluminance, ao, cloudsShadows);
        }
    #else

        if(clamp(textureCoords, vec2(0.0), vec2(GI_SCALE)) == textureCoords) {

            pathtrace(color.rgb, vec3(tempCoords, material.depth0), direct, indirect);

            #if GI_TEMPORAL_ACCUMULATION == 1
                float frameWeight = 1.0 / max(color.a * float(linearizeDepthFast(material.depth0) >= MC_HAND_DEPTH), 1.0);

                color.rgb = mix(history.rgb, color.rgb, frameWeight);

                vec3 prevDirect   = texture(DIRECT_BUFFER,   prevPosition.xy).rgb;
                vec3 prevIndirect = texture(INDIRECT_BUFFER, prevPosition.xy).rgb;

                direct   = max0(mix(prevDirect  , direct  , frameWeight));
                indirect = max0(mix(prevIndirect, indirect, frameWeight));

                #if GI_FILTER == 1
                    float luminance = luminance(color.rgb);
                    temporalData.rg = vec2(luminance, luminance * luminance);

                    vec2 prevMoments     = texture(MOMENTS_BUFFER, prevPosition.xy).rg;
                         temporalData.rg = mix(prevMoments, temporalData.rg, frameWeight);
                         temporalData.b  = sqrt(abs(temporalData.g - temporalData.r * temporalData.r));
                #endif
            #endif
        }
    #endif
}
