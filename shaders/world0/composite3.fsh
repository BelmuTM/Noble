/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 330 compatibility

varying vec2 texCoords;

#include "/settings.glsl"
#include "/common.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/post/taa.glsl"

/*
const int colortex6Format = RGBA16F;
const bool colortex6Clear = false;
*/

#if GI_TEMPORAL_ACCUMULATION == 1
    vec3 temporalAccumulation(sampler2D prevTex, vec3 currColor, vec3 viewPos, vec3 normal) {
        vec2 prevTexCoords = reprojection(vec3(texCoords, texture(depthtex0, texCoords).r)).xy;
        vec3 prevColor = texture(prevTex, prevTexCoords).rgb;
        /*
        float depthAt = linearizeDepth(texture(depthtex0, prevTexCoords).r);
        float depth = linearizeDepth(texture(depthtex0, texCoords).r);
        */
        vec3 normalAt = normalize(decodeNormal(texture(colortex1, prevTexCoords).xy));
        float totalWeight = 0.92 * float(
               abs(normalAt.x - normal.x) <= EDGE_STOP_THRESHOLD
            && abs(normalAt.y - normal.y) <= EDGE_STOP_THRESHOLD
            && abs(normalAt.z - normal.z) <= EDGE_STOP_THRESHOLD
        );

        #if ACCUMULATION_VELOCITY_WEIGHT == 1
            totalWeight = 0.99 * float(distance(texCoords, prevTexCoords) <= 1e-6);
        #endif
        totalWeight *= float(saturate(prevTexCoords) == prevTexCoords);

        return mix(currColor, prevColor, totalWeight);
    }
#endif

void main() {
    vec3 globalIllumination = vec3(0.0);
    float ambientOcclusion = 1.0;

    bool isMetal = texture(colortex2, texCoords).g * 255.0 > 229.5;

    if(!isSky(texCoords) && !isMetal) {
        vec3 viewPos = getViewPos(texCoords);
        vec3 normal = normalize(decodeNormal(texture(colortex1, texCoords).xy));
        
        #if GI == 1
            vec2 scaledUv = texCoords * GI_RESOLUTION; 
            #if GI_FILTER == 1
                vec3 scaledViewPos = getViewPos(scaledUv);
                vec3 scaledNormal = normalize(decodeNormal(texture(colortex1, scaledUv).xy));

                globalIllumination = heavyGaussianFilter(scaledUv, scaledViewPos, scaledNormal, colortex5, vec2(1.0, 0.0)).rgb;
            #else
                globalIllumination = texture(colortex5, scaledUv).rgb;
            #endif

            #if GI_TEMPORAL_ACCUMULATION == 1
                globalIllumination = saturate(temporalAccumulation(colortex6, globalIllumination, viewPos, normal));
            #endif
        #else 
            #if AO == 1
                #if AO_FILTER == 1
                    ambientOcclusion = fastGaussianFilter(texCoords, viewPos, normal, colortex5, vec2(1.0, 0.0)).a;
                #else
                    ambientOcclusion = texture(colortex5, texCoords).a;
                #endif
            #endif
        #endif
    }

    /*DRAWBUFFERS:56*/
    gl_FragData[0] = vec4(ambientOcclusion);
    gl_FragData[1] = vec4(globalIllumination, texture(depthtex0, texCoords).r);
}
