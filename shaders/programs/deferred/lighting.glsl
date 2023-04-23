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

#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/brdf.glsl"

#include "/include/atmospherics/celestial.glsl"

#if GI == 1
    #include "/include/fragment/pathtracer.glsl"
#endif

void main() {
    vec3 viewPosition0 = getViewPosition0(texCoords);

    #if GI == 1
        vec2 tempCoords = texCoords * rcp(GI_SCALE);
    #else
        vec2 tempCoords = texCoords;
    #endif

    if(isSky(texCoords)) {
        vec3 sky = computeAtmosphere(viewPosition0);
        #if GI == 1
            direct = sky;
        #else
            color.rgb = sky;
        #endif
        return;
    }

    Material material = getMaterial(tempCoords);

    #if HARDCODED_SSS == 1
        if(material.blockId >= 8 && material.blockId < 13 && material.subsurface <= EPS) material.subsurface = HARDCODED_SSS_VAL;
    #endif

    #if AO_FILTER == 1 && GI == 0 || GI == 1
        vec3 currPosition = vec3(texCoords, material.depth0);
        vec3 prevPosition = currPosition - getVelocity(currPosition);
        vec4 history      = texture(DEFERRED_BUFFER, prevPosition.xy);

        #if RENDER_MODE == 0
            float prevDepth = exp2(texture(MOMENTS_BUFFER, prevPosition.xy).a);
            float weight    = pow(exp(-abs(linearizeDepth(material.depth0) - linearizeDepth(prevDepth))), TEMPORAL_DEPTH_WEIGHT_SIGMA);

            temporalData.a = log2(material.depth0);
        #else
            float weight = float(hideGUI);
        #endif

        color.a = (history.a * weight * float(saturate(prevPosition.xy) == prevPosition.xy) * float(!isHand(texCoords))) + 1.0;
    #endif

    #if GI == 0
        color.rgb = vec3(0.0);

        if(material.F0 * maxVal8 <= 229.5) {
            vec3 skyIlluminance = vec3(0.0), directIlluminance = vec3(0.0);
            float cloudsShadows = 1.0; vec4 shadowmap = vec4(1.0, 1.0, 1.0, 0.0);

            #if defined WORLD_OVERWORLD
                skyIlluminance    = texture(ILLUMINANCE_BUFFER, texCoords).rgb;
                directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;

                #if CLOUDS_SHADOWS == 1 && PRIMARY_CLOUDS == 1
                    cloudsShadows = getCloudsShadows(viewToScene(viewPosition0));
                #endif

                #if SHADOWS == 1
                    shadowmap = texture(SHADOWMAP_BUFFER, texCoords);
                #endif
            #endif

            float ao = 1.0;
            #if AO == 1
                ao = texture(INDIRECT_BUFFER, texCoords).a;
            #endif

            color.rgb = max0(computeDiffuse(viewPosition0, shadowVec, material, shadowmap, directIlluminance, skyIlluminance, ao, cloudsShadows));
        }
    #else

        if(clamp(texCoords, vec2(0.0), vec2(GI_SCALE)) == texCoords) {

            pathtrace(color.rgb, vec3(tempCoords, material.depth0), direct, indirect);

            #if GI_TEMPORAL_ACCUMULATION == 1
                float frameWeight = 1.0 / max(color.a * float(linearizeDepth(material.depth0) >= MC_HAND_DEPTH), 1.0);

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
