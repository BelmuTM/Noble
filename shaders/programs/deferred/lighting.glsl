/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#if GI == 1
    /* RENDERTARGETS: 5,9,10,11 */

    layout (location = 0) out vec4 color;
    layout (location = 1) out vec3 directColor;
    layout (location = 2) out vec3 indirectColor;
    layout (location = 3) out vec4 colortex11Write;
#else
    /* RENDERTARGETS: 11,13 */

    layout (location = 0) out vec4 colortex11Write;
    layout (location = 1) out vec4 color;
#endif

#include "/include/common.glsl"

#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/brdf.glsl"

#include "/include/atmospherics/celestial.glsl"

#if GI == 1
    #include "/include/fragment/pathtracer.glsl"
#endif

#if GI == 1 && GI_TEMPORAL_ACCUMULATION == 1

    void temporalAccumulation(Material material, inout vec3 color, vec3 prevColor, vec3 prevPos, inout vec3 direct, inout vec3 indirect, inout vec3 moments, float frames) {
        float weight = 1.0 / max(frames, 1.0);

        // Thanks SixthSurge#3922 for the help with moments
        #if GI_FILTER == 1
            vec2 prevMoments = texture(colortex11, prevPos.xy).rg;
                  moments.rg = mix(prevMoments, moments.rg, weight);
                  moments.b  = abs(moments.g - moments.r * moments.r);
        #endif

        color = mix(prevColor, color, weight);

        vec3 prevColorDirect   = texture(colortex9,  prevPos.xy).rgb;
        vec3 prevColorIndirect = texture(colortex10, prevPos.xy).rgb;

        direct   = max0(mix(prevColorDirect  , direct  , weight));
        indirect = max0(mix(prevColorIndirect, indirect, weight));
    }
#endif

void main() {
    vec3 viewPos0 = getViewPos0(texCoords);

    #if GI == 1
        vec2 tempCoords = texCoords * rcp(GI_SCALE);
    #else
        vec2 tempCoords = texCoords;
    #endif

    if(isSky(texCoords)) {
        vec3 sky = computeAtmosphere(viewPos0);
        #if GI == 1
            directColor.rgb = sky;
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
        vec3 currPos   = vec3(texCoords, material.depth0);
        vec3 prevPos   = currPos - getVelocity(currPos);

        #if GI == 1
            vec4 prevColor = texture(colortex5, prevPos.xy);
        #else
            vec4 prevColor = texture(colortex13, prevPos.xy);
        #endif

        #if RENDER_MODE == 0
            float prevDepth = exp2(texture(colortex11, prevPos.xy).a);
            float weight    = pow(exp(-abs(linearizeDepth(material.depth0) - linearizeDepth(prevDepth))), TEMPORAL_DEPTH_WEIGHT_SIGMA);

            colortex11Write.a = log2(material.depth0);
        #else
            float weight = float(hideGUI);
        #endif

        color.a = (prevColor.a * weight * float(clamp01(prevPos.xy) == prevPos.xy)) + 1.0;
    #endif

    #if GI == 0
        color.rgb = vec3(0.0);

        if(material.F0 * maxVal8 <= 229.5) {
            vec3 skyIlluminance = vec3(0.0), directIlluminance = vec3(0.0);
            float cloudsShadows = 1.0; vec4 shadowmap = vec4(1.0, 1.0, 1.0, 0.0);

            #if defined WORLD_OVERWORLD
                skyIlluminance    = texture(colortex6, texCoords).rgb;
                directIlluminance = texelFetch(colortex6, ivec2(0), 0).rgb;

                #if CLOUDS_SHADOWS == 1 && PRIMARY_CLOUDS == 1
                    cloudsShadows = getCloudsShadows(viewToScene(viewPos0));
                #endif

                #if SHADOWS == 1
                    shadowmap = texture(colortex3, texCoords);
                #endif
            #endif

            float ao = 1.0;
            #if AO == 1
                ao = texture(colortex10, texCoords).a;
            #endif

            color.rgb = max0(computeDiffuse(viewPos0, shadowVec, material, shadowmap, directIlluminance, skyIlluminance, ao, cloudsShadows));
        }
    #else

        if(clamp(texCoords, vec2(0.0), vec2(GI_SCALE)) == texCoords) {
            pathTrace(color.rgb, vec3(tempCoords, material.depth0), directColor, indirectColor);

            #if GI_FILTER == 1
                float luminance    = luminance(color.rgb);
                colortex11Write.rg = vec2(luminance, luminance * luminance);
            #endif

            #if GI_TEMPORAL_ACCUMULATION == 1
                temporalAccumulation(material, color.rgb, prevColor.rgb, prevPos, directColor, indirectColor, colortex11Write.rgb, color.a);
            #endif
        }
    #endif
}
