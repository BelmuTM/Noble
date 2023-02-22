/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
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

#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/brdf.glsl"

#include "/include/atmospherics/celestial.glsl"

#if GI == 1
    #include "/include/fragment/pathtracer.glsl"
#endif

#if GI == 1 && GI_TEMPORAL_ACCUMULATION == 1

    void temporalAccumulation(Material mat, inout vec3 color, vec3 prevColor, vec3 prevPos, inout vec3 direct, inout vec3 indirect, inout vec3 moments, float frames) {
        float weight = clamp01(1.0 - (1.0 / max(frames, 1.0)));

        #if ACCUMULATION_VELOCITY_WEIGHT == 1
            weight *= hideGUI;
        #endif

        // Thanks SixthSurge#3922 for the help with moments
        #if GI_FILTER == 1
            vec2 prevMoments = texture(colortex11, prevPos.xy).rg;
                  moments.rg = mix(moments.rg, prevMoments, weight);
                  moments.b  = abs(moments.g - moments.r * moments.r);
        #endif

        color = mix(color, prevColor, weight);

        vec3 prevColorDirect   = texture(colortex9,  prevPos.xy).rgb;
        vec3 prevColorIndirect = texture(colortex10, prevPos.xy).rgb;

        direct   = max0(mix(direct,   prevColorDirect,   weight));
        indirect = max0(mix(indirect, prevColorIndirect, weight));
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

    Material mat = getMaterial(tempCoords);

    #if HARDCODED_SSS == 1
        if(mat.blockId >= 8 && mat.blockId < 13 && mat.subsurface <= EPS) mat.subsurface = HARDCODED_SSS_VAL;
    #endif

    #if AO_FILTER == 1 && GI == 0 || GI == 1
        vec3 currPos   = vec3(texCoords, mat.depth0);
        vec3 prevPos   = currPos - getVelocity(currPos);

        #if GI == 1
            vec4 prevColor = texture(colortex5, prevPos.xy);
        #else
            vec4 prevColor = texture(colortex13, prevPos.xy);
        #endif

        #if ACCUMULATION_VELOCITY_WEIGHT == 0
            float prevDepth   = exp2(texture(colortex11, prevPos.xy).a);
            float depthWeight = pow(exp(-abs(linearizeDepth(mat.depth0) - linearizeDepth(prevDepth))), TEMPORAL_DEPTH_WEIGHT_SIGMA);

            colortex11Write.a = log2(mat.depth0);
        #else
            float depthWeight = 1.0;
        #endif

        color.a = (prevColor.a * depthWeight * float(clamp01(prevPos.xy) == prevPos.xy)) + 1.0;
    #endif

    #if GI == 0
        color.rgb = vec3(0.0);

        if(mat.F0 * maxVal8 <= 229.5) {
            vec3 skyIlluminance = vec3(0.0), directIlluminance = vec3(0.0);
            float cloudsShadows = 1.0; vec4 shadowmap = vec4(1.0, 1.0, 1.0, 0.0);

            #ifdef WORLD_OVERWORLD
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

            color.rgb = computeDiffuse(viewPos0, shadowVec, mat, shadowmap, directIlluminance, skyIlluminance, ao, cloudsShadows);
        }
    #else

        if(clamp(texCoords, vec2(0.0), vec2(GI_SCALE)) == texCoords) {
            pathTrace(color.rgb, vec3(tempCoords, mat.depth0), directColor, indirectColor);

            #if GI_FILTER == 1
                float luminance    = luminance(color.rgb);
                colortex11Write.rg = vec2(luminance, luminance * luminance);
            #endif

            #if GI_TEMPORAL_ACCUMULATION == 1
                temporalAccumulation(mat, color.rgb, prevColor.rgb, prevPos, directColor, indirectColor, colortex11Write.rgb, color.a);
            #endif
        }
    #endif
}
