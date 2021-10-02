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
#include "/lib/fragment/brdf.glsl"
#include "/lib/fragment/raytracer.glsl"
#include "/lib/fragment/ao.glsl"
#include "/lib/fragment/ptgi.glsl"
#include "/lib/post/taa.glsl"

/*
const int colortex5Format = RGBA16F;
const int colortex6Format = RGBA16F;
const bool colortex6Clear = false;
*/

#if GI_TEMPORAL_ACCUMULATION == 1
    vec3 temporalAccumulation(sampler2D prevTex, vec3 currColor, vec3 viewPos, vec3 normal) {
        vec2 prevTexCoords = reprojection(vec3(texCoords, texture(depthtex0, texCoords).r)).xy;
        vec3 prevColor = texture(prevTex, prevTexCoords).rgb;
        /*
        vec3 normalAt = normalize(decodeNormal(texture(colortex1, prevTexCoords).xy));
        vec3 delta = normal - normalAt;
        float normalWeight = max(0.0, exp(-dot(delta, delta)));
        */

        vec3 prevPos = viewToWorld(getViewPos(prevTexCoords));
        vec3 delta = viewToWorld(viewPos) - prevPos;
        float posWeight = max(0.0, exp(-dot(delta, delta) / 0.4));
        float totalWeight = 0.96 * posWeight;

        #if ACCUMULATION_VELOCITY_WEIGHT == 1
            totalWeight = 0.985 * float(distance(texCoords, prevTexCoords) <= 1e-6);
        #endif
        totalWeight *= float(saturate(prevTexCoords) == prevTexCoords);

        return mix(currColor, prevColor, totalWeight);
    }
#endif

void main() {
    vec4 Result = texture(colortex0, texCoords);
    vec3 globalIllumination = vec3(0.0);
    float ambientOcclusion = 1.0;

    #if GI == 1
        /* Downscaling Global Illumination */
        vec2 scaledUv = texCoords * (1.0 / GI_RESOLUTION);

        if(clamp(texCoords, vec2(0.0), vec2(GI_RESOLUTION)) == texCoords && !isSky(scaledUv)) {
            vec3 positionAt = vec3(scaledUv, texture(depthtex0, scaledUv).r);
            globalIllumination = computePTGI(positionAt);
        }

        #if GI_TEMPORAL_ACCUMULATION == 1
            vec3 viewPos = getViewPos(texCoords);
            vec3 normal = normalize(decodeNormal(texture(colortex1, texCoords).xy));
            
            globalIllumination = saturate(temporalAccumulation(colortex6, globalIllumination, viewPos, normal));
        #endif
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
    gl_FragData[2] = vec4(globalIllumination, 1.0);
}

