#version 400 compatibility
#include "/programs/extensions.glsl"

/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

varying vec2 texCoords;

#include "/settings.glsl"
#include "/programs/common.glsl"

#include "/lib/atmospherics/atmosphere.glsl"

#include "/lib/fragment/brdf.glsl"
#include "/lib/fragment/raytracer.glsl"
#include "/lib/fragment/pathtracer.glsl"
#include "/lib/fragment/ao.glsl"

/*
const int colortex5Format = RGBA16F;
const int colortex6Format = RGBA16F;
const bool colortex6Clear = false;
*/

#if GI_TEMPORAL_ACCUMULATION == 1
    #include "/lib/post/taa.glsl"

    vec3 temporalAccumulation(sampler2D prevTex, vec3 currColor, vec3 viewPos, vec3 normal, inout float historyFrames) {
        vec2 prevTexCoords = reprojection(vec3(texCoords, texture(depthtex0, texCoords).r)).xy;
        vec3 prevColor = texture(prevTex, prevTexCoords).rgb;

        float totalWeight = float(clamp01(prevTexCoords) == prevTexCoords);
        #if ACCUMULATION_VELOCITY_WEIGHT == 0
            vec3 prevPos = viewToWorld(getViewPos(prevTexCoords));
            vec3 delta = viewToWorld(viewPos) - prevPos;
            float posWeight = max(0.0, exp(-dot(delta, delta) * 3.0));
            totalWeight *= 0.96 * posWeight;
        #else
            historyFrames = hasMoved() ? 1.0 : texture(prevTex, texCoords).a + 1.0;
            totalWeight *= 1.0 - (1.0 / max(historyFrames, 1.0));
        #endif

        return clamp(mix(currColor, prevColor, totalWeight), vec3(0.0), vec3(65e3));
    }
#endif

void main() {
    vec4 Result = texture(colortex0, texCoords);
    vec3 globalIllumination = vec3(0.0);
    float ambientOcclusion = 1.0;
    float historyFrames = texture(colortex6, texCoords).a;

    #if GI == 1
        /* Downscaling Global Illumination */
        vec2 scaledUv = texCoords * (1.0 / GI_RESOLUTION);

        if(clamp(texCoords, vec2(0.0), vec2(GI_RESOLUTION + 1e-3)) == texCoords && !isSky(scaledUv)) {
            vec3 positionAt = vec3(scaledUv, texture(depthtex0, scaledUv).r);
            globalIllumination = pathTrace(positionAt);

            #if GI_TEMPORAL_ACCUMULATION == 1
                vec3 viewPos = getViewPos(texCoords);
                vec3 normal = normalize(decodeNormal(texture(colortex1, texCoords).xy));
            
                globalIllumination = temporalAccumulation(colortex6, globalIllumination, viewPos, normal, historyFrames);
            #endif
        }
    #else
        if(!isSky(texCoords)) {
            #if AO == 1
                vec3 viewPos = getViewPos(texCoords);
                vec3 normal = normalize(decodeNormal(texture(colortex1, texCoords).xy));
            
                ambientOcclusion = AO_TYPE == 0 ? computeSSAO(viewPos, normal) : computeRTAO(viewPos, normal);

                #if AO_FILTER == 0
                    Result.rgb *= ambientOcclusion;
                #endif
            #endif
        }
    #endif

    /*DRAWBUFFERS:056*/
    gl_FragData[0] = Result;
    gl_FragData[1] = vec4(globalIllumination, ambientOcclusion);
    gl_FragData[2] = vec4(globalIllumination, historyFrames);
}
