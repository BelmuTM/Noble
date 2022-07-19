/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if GI == 1
    /* RENDERTARGETS: 5,10,11,12 */

    layout (location = 0) out vec4 color;
    layout (location = 1) out vec4 history0;
    layout (location = 2) out vec3 history1;
    layout (location = 3) out vec4 moments;
#else
    /* RENDERTARGETS: 5,12 */

    layout (location = 0) out vec4 color;
    layout (location = 1) out vec4 moments;
#endif

#include "/include/fragment/brdf.glsl"

#include "/include/atmospherics/celestial.glsl"
#include "/include/atmospherics/atmosphere.glsl"

#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/pathtracer.glsl"
#include "/include/fragment/shadows.glsl"

#if GI == 1 && GI_TEMPORAL_ACCUMULATION == 1

    void temporalAccumulation(Material mat, inout vec3 color, vec3 prevColor, vec3 prevPos, inout vec3 direct, inout vec3 indirect, inout vec3 moments, float frames) {
        float weight = clamp01(1.0 - (1.0 / max(frames, 1.0)));

        #if ACCUMULATION_VELOCITY_WEIGHT == 1
            weight *= hideGUI;
        #endif

        color           = mix(color, prevColor, weight);
        float luminance = luminance(color);

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
        tempCoords = texCoords * rcp(GI_RESOLUTION);
    #endif

    vec3 viewPos0 = getViewPos0(tempCoords);

    if(isSky(tempCoords)) {
        color.rgb = computeSky(viewPos0);
        return;
    }

    Material mat = getMaterial(tempCoords);

    vec3 prevPos   = reproject(vec3(texCoords, mat.depth0));
    vec4 prevColor = texture(colortex5, prevPos.xy);

    float depthWeight = getDepthWeight(mat.depth0, exp2(texture(colortex9, prevPos.xy).a), 1.5);

    #if GI == 1 && ACCUMULATION_VELOCITY_WEIGHT == 1
        depthWeight  = 1.0;
    #endif

    color.a   = (prevColor.a * depthWeight * float(clamp01(prevPos.xy) == prevPos.xy)) + 1.0;
    moments.a = texture(colortex12, prevPos.xy).a + 1.0;

    #if GI == 0
        color.rgb = vec3(0.0);

        if(mat.F0 * maxVal8 <= 229.5) {
            vec3 skyIlluminance = vec3(0.0);
            vec4 shadowmap      = vec4(1.0, 1.0, 1.0, 0.0);

            #ifdef WORLD_OVERWORLD
                skyIlluminance = texture(colortex6, texCoords).rgb;
                shadowmap      = texture(colortex3, texCoords);
            #endif

            float ao = 1.0;
            #if AO == 1
                ao = texture(colortex10, texCoords).a;
            #endif

            color.rgb = computeDiffuse(viewPos0, shadowDir, mat, shadowmap, sampleDirectIlluminance(), skyIlluminance, clamp01(ao));
        }
    #else

        if(clamp(texCoords, vec2(0.0), vec2(GI_RESOLUTION)) == texCoords) {
            pathTrace(color.rgb, vec3(tempCoords, mat.depth0), history0.rgb, history1);

            #if GI_TEMPORAL_ACCUMULATION == 1
                temporalAccumulation(mat, color.rgb, prevColor.rgb, prevPos, history0.rgb, history1, moments.rgb, color.a);
            #endif
        }
    #endif
}
