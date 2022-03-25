/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 5,4,10,11 */

layout (location = 0) out vec4 color;
layout (location = 1) out vec4 historyBuffer;
layout (location = 2) out vec3 direct;
layout (location = 3) out vec3 indirect;

#include "/include/utility/blur.glsl"

#include "/include/fragment/brdf.glsl"

#include "/include/atmospherics/celestial.glsl"
#include "/include/atmospherics/atmosphere.glsl"

#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/pathtracer.glsl"
#include "/include/fragment/shadows.glsl"

#if GI == 1 && GI_TEMPORAL_ACCUMULATION == 1
    #include "/include/post/taa.glsl"

    void temporalAccumulation(Material mat, inout vec4 color, inout vec3 indirectBounce, inout float frames) {
        vec3 prevPos           = reprojection(vec3(texCoords, mat.depth0));
        vec4 prevColor         = texture(colortex4, prevPos.xy);
        vec3 prevColorIndirect = texture(colortex11, prevPos.xy).rgb;

        if(mat.depth0 == 0.0) return;

        float blendWeight = float(clamp01(prevPos.xy) == prevPos.xy);
        frames            = prevColor.a + 1.0;

        #if ACCUMULATION_VELOCITY_WEIGHT == 0
            float normalWeight = exp(-pow2(1.0 - dot(mat.normal, texture(colortex9, prevPos.xy).rgb * 2.0 - 1.0)) * NORMAL_WEIGHT_STRENGTH);
            float depthWeight  = exp(-pow2(linearizeDepth(prevPos.z) - linearizeDepth(texture(colortex9, prevPos.xy).a)) * DEPTH_WEIGHT_STRENGTH);
            blendWeight       *= (normalWeight * depthWeight);
        #else
            frames = hasMoved() ? 0.0 : frames;
        #endif

        blendWeight *= 1.0 - (1.0 / max(frames, 1.0));
        blendWeight  = maxEps(blendWeight);

        float currLuma = luminance(color.rgb);
        color.rgb      = mix(color.rgb, prevColor.rgb, blendWeight);
        indirectBounce = mix(indirectBounce, prevColorIndirect, blendWeight);
        float avgLum   = mix(currLuma, luminance(prevColor.rgb), blendWeight);
        color.a        = mix(pow2(currLuma - avgLum), color.a, blendWeight);
    }
#endif

void main() {
    color.rgb = vec3(0.0);

    vec2 tempCoords = texCoords;
    #if GI == 1
        tempCoords = texCoords * (1.0 / GI_RESOLUTION);
    #endif

    vec3 viewPos0 = getViewPos0(tempCoords);

    if(isSky(tempCoords)) {
        color.rgb = computeSky(viewPos0, true);
        return;
    }

    Material mat   = getMaterial(tempCoords);
    vec4 shadowmap = texture(colortex3, tempCoords);

    vec3 skyIlluminance = vec3(0.0);
    #ifdef WORLD_OVERWORLD
        skyIlluminance = texture(colortex6, tempCoords).rgb;
    #endif

    color.a = texture(colortex5, tempCoords).a;

    //vec2 causticsCoords = distortShadowSpace(worldToShadow(viewToWorld(viewPos0))).xy;
    //shadowmap.rgb += texture(shadowcolor1, causticsCoords * 0.5 + 0.5).a;

    #if GI == 0
        if(!mat.isMetal) {
            #if AO == 1
                #if SSAO_FILTER == 1
                    shadowmap.a = gaussianBlur(tempCoords, colortex3, 1.2, 2.0, 4).a;
                #endif
            #endif

            color.rgb = computeDiffuse(viewPos0, shadowDir, mat, shadowmap, sampleDirectIlluminance(), skyIlluminance);
        }
    #else
        if(clamp(texCoords, vec2(0.0), vec2(GI_RESOLUTION + 1e-3)) == texCoords) {
            pathTrace(color.rgb, vec3(tempCoords, mat.depth1), direct, indirect);
            //color.rgb -= direct;

            #if GI_TEMPORAL_ACCUMULATION == 1
                temporalAccumulation(mat, color, indirect, historyBuffer.a);
            #endif
        }
    #endif

    historyBuffer.rgb = color.rgb;
}
