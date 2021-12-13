/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/atmospherics/atmosphere.glsl"
#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/pathtracer.glsl"

#if GI_TEMPORAL_ACCUMULATION == 1
    #include "/include/post/taa.glsl"

    vec3 temporalAccumulation(sampler2D prevTex, vec3 currColor, vec3 viewPos, vec3 normal, inout float historyFrames) {
        vec2 prevTexCoords = reprojection(vec3(texCoords, texture(depthtex0, texCoords).r)).xy;
        vec3 prevColor     = texture(prevTex, prevTexCoords).rgb;

        float totalWeight = float(clamp01(prevTexCoords) == prevTexCoords);
        #if ACCUMULATION_VELOCITY_WEIGHT == 0
            vec3 prevPos    = viewToWorld(getViewPos0(prevTexCoords));
            vec3 delta      = viewToWorld(viewPos) - prevPos;
            float posWeight = max0(exp(-dot(delta, delta) * 3.0));

            float currLuma   = luminance(currColor), prevLuma = luminance(prevColor);
            float lumaWeight = exp(-(abs(currLuma - prevLuma) / max(currLuma, max(prevLuma, TAA_LUMA_MIN))));
	        lumaWeight       = mix(TAA_STRENGTH, TAA_STRENGTH, lumaWeight * lumaWeight);

            totalWeight     *= pow2(lumaWeight) * posWeight;
        #else
            historyFrames = hasMoved() ? 1.0 : texture(prevTex, texCoords).a + 1.0;
            totalWeight  *= 1.0 - (1.0 / max(historyFrames, 1.0));
        #endif

        return clamp32(mix(currColor, prevColor, totalWeight));
    }
#endif

void main() {
    vec3 globalIllumination = vec3(0.0);
    float historyFrames     = texture(colortex6, texCoords).a;

    #if GI == 1
        vec2 scaledUv = texCoords * (1.0 / GI_RESOLUTION);

        if(clamp(texCoords, vec2(0.0), vec2(GI_RESOLUTION + 1e-3)) == texCoords && !isSky(scaledUv)) {
            globalIllumination = pathTrace(vec3(scaledUv, texture(depthtex0, scaledUv).r));

            #if GI_TEMPORAL_ACCUMULATION == 1
                vec3 viewPos = getViewPos0(texCoords);
                vec3 normal  = normalize(decodeNormal(texture(colortex1, texCoords).xy));

                globalIllumination = temporalAccumulation(colortex6, globalIllumination, viewPos, normal, historyFrames);
            #endif
        }
    #endif

    /*DRAWBUFFERS:56*/
    gl_FragData[0] = vec4(globalIllumination, 1.0);
    gl_FragData[1] = vec4(globalIllumination, historyFrames);
}
