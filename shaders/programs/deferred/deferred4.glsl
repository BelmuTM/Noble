/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if GI == 1
    /* RENDERTARGETS: 5,9,10,11 */

    layout (location = 0) out vec4 color;
    layout (location = 1) out vec3 historyCol0;
    layout (location = 2) out vec3 historyCol1;
    layout (location = 3) out vec4 moments;
#else
    /* RENDERTARGETS: 5,13,11 */

    layout (location = 0) out vec3 deferredCol;
    layout (location = 1) out vec4 color;
    layout (location = 2) out vec4 moments;
#endif

#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/brdf.glsl"

#include "/include/atmospherics/celestial.glsl"
#include "/include/atmospherics/atmosphere.glsl"

#if GI == 1
    #include "/include/fragment/pathtracer.glsl"
#endif

#if GI == 1 && GI_TEMPORAL_ACCUMULATION == 1

    void temporalAccumulation(Material mat, inout vec3 color, vec3 prevColor, vec3 prevPos, inout vec3 direct, inout vec3 indirect, inout vec3 moments, float frames) {
        float weight = clamp01(1.0 - (1.0 / max(frames, 1.0)));

        #if ACCUMULATION_VELOCITY_WEIGHT == 1
            weight *= hideGUI;
        #endif

        color = mix(color, prevColor, weight);
        float luminance = luminance(color);

        // Thanks SixthSurge#3922 for the help with moments
        #if GI_FILTER == 1
            vec2 prevMoments = texture(colortex11, prevPos.xy).rg;
            vec2 currMoments = vec2(luminance, luminance * luminance);
                 moments.rg  = mix(currMoments, prevMoments, weight);
                 moments.b   = moments.g - moments.r * moments.r;
        #endif

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
        vec3 sky = computeSky(viewPos0);
        #if GI == 1
            historyCol0.rgb = sky;
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
            float depthWeight = getDepthWeight(mat.depth0, exp2(texture(colortex11, prevPos.xy).a), 1.0);
        #else
            float depthWeight = 1.0;
        #endif

        color.a   = (prevColor.a * depthWeight * float(clamp01(prevPos.xy) == prevPos.xy)) + 1.0;
        moments.a = log2(mat.depth0);
    #endif

    #if GI == 0
        color.rgb = vec3(0.0);

        if(mat.F0 * maxVal8 <= 229.5) {
            vec4 shadowmap      = vec4(1.0, 1.0, 1.0, 0.0);
            vec3 skyIlluminance = vec3(0.0), directIlluminance = vec3(0.0);

            #ifdef WORLD_OVERWORLD
                shadowmap         = texture(colortex3,  texCoords);
                skyIlluminance    = texture(colortex6,  texCoords).rgb;
                directIlluminance = texelFetch(colortex6, ivec2(0), 0).rgb;
            #endif

            float ao = 1.0;
            #if AO == 1
                ao = texture(colortex10, texCoords).a;
            #endif

            color.rgb = computeDiffuse(viewPos0, shadowVec, mat, shadowmap, directIlluminance, skyIlluminance, ao);
        }

        deferredCol = color.rgb;
    #else

        if(clamp(texCoords, vec2(0.0), vec2(GI_SCALE)) == texCoords) {
            pathTrace(color.rgb, vec3(tempCoords, mat.depth0), historyCol0, historyCol1);

            #if GI_TEMPORAL_ACCUMULATION == 1
                temporalAccumulation(mat, color.rgb, prevColor.rgb, prevPos, historyCol0, historyCol1, moments.rgb, color.a);
            #endif
        }
    #endif
}
