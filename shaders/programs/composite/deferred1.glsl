/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 5,4,10,11,12 */

layout (location = 0) out vec3 color;
layout (location = 1) out vec4 historyBuffer;
layout (location = 2) out vec3 direct;
layout (location = 3) out vec3 indirect;
layout (location = 4) out vec3 moments;

#include "/include/utility/blur.glsl"

#include "/include/fragment/brdf.glsl"

#include "/include/atmospherics/celestial.glsl"
#include "/include/atmospherics/atmosphere.glsl"

#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/pathtracer.glsl"
#include "/include/fragment/shadows.glsl"

#if GI == 1 && GI_TEMPORAL_ACCUMULATION == 1
    #include "/include/post/taa.glsl"

    void temporalAccumulation(Material mat, inout vec3 color, inout vec3 direct, inout vec3 indirect, inout float frames, inout vec3 moments) {
        vec3 prevPos   = reprojection(vec3(texCoords, mat.depth0));
        vec4 prevColor = texture(colortex4, prevPos.xy);

        float depthWeight = 1.0;
        #if ACCUMULATION_VELOCITY_WEIGHT == 0
            depthWeight = pow(exp(-abs(linearizeDepth(mat.depth0) - linearizeDepth(texture(colortex9, prevPos.xy).a))), 2.0);
        #else
            if(hideGUI == 0) {
                color = mat.albedo;
                return;
            }
            frames = hideGUI == 0 ? 0.0 : frames;
        #endif

              frames = (prevColor.a * depthWeight * float(clamp01(prevPos.xy) == prevPos.xy)) + 1.0;
        float weight = clamp01(1.0 - (1.0 / max(frames, 1.0)));

        color           = mix(color, prevColor.rgb, weight);
        float luminance = luminance(color);

        moments.z = 0.0;

        // Thanks SixthSurge#3922 for the help with moments
        vec2 prevMoments = texture(colortex12, prevPos.xy).xy;
        vec2 currMoments = vec2(luminance, luminance * luminance);
             moments.xy  = mix(currMoments, prevMoments, weight);
             moments.z   = moments.y - moments.x * moments.x;

        vec3 prevColorDirect   = texture(colortex10, prevPos.xy).rgb;
        vec3 prevColorIndirect = texture(colortex11, prevPos.xy).rgb;

        direct   = max0(mix(direct,   prevColorDirect,   weight));
        indirect = max0(mix(indirect, prevColorIndirect, weight));
    }
#endif

void main() {
    vec2 tempCoords = texCoords;
    #if GI == 1
        tempCoords = texCoords * (1.0 / GI_RESOLUTION);
    #endif

    vec3 viewPos0 = getViewPos0(tempCoords);

    if(isSky(tempCoords)) {
        color = computeSky(viewPos0);
        return;
    }

    Material mat   = getMaterial(tempCoords);
    vec4 shadowmap = texture(colortex3, tempCoords);

    vec3 skyIlluminance = vec3(0.0);
    #ifdef WORLD_OVERWORLD
        skyIlluminance = texture(colortex6, tempCoords).rgb;
    #endif

    #if GI == 0
        if(!mat.isMetal) {
            #if AO == 1
                #if SSAO_FILTER == 1
                    shadowmap.a = gaussianBlur(tempCoords, colortex3, 1.2, 2.0, 4).a;
                #endif
            #endif

            color = computeDiffuse(viewPos0, shadowDir, mat, shadowmap, sampleDirectIlluminance(), skyIlluminance);
        }
    #else
        if(clamp(texCoords, vec2(0.0), vec2(GI_RESOLUTION)) == texCoords) {
            pathTrace(color, vec3(tempCoords, mat.depth0), direct, indirect);

            #if GI_TEMPORAL_ACCUMULATION == 1
                temporalAccumulation(mat, color, direct, indirect, historyBuffer.a, moments);
            #endif
        }
    #endif

    historyBuffer.rgb = color;
}
