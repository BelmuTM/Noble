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
#include "/lib/uniforms.glsl"
#include "/lib/fragment/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/post/taa.glsl"

/*
const int colortex6Format = RGBA16F;
const bool colortex6Clear = false;
*/

#if GI_TEMPORAL_ACCUMULATION == 1
    vec3 temporalAccumulation(sampler2D prevTex, vec3 currColor, vec3 normal) {
        vec2 prevTexCoords = reprojection(vec3(texCoords, texture2D(depthtex1, texCoords).r)).xy;
        vec3 prevColor = texture2D(prevTex, prevTexCoords).rgb;
        prevColor = neighbourhoodClipping(prevTex, prevColor);

        vec3 normalAt = normalize(decodeNormal(texture2D(colortex1, prevTexCoords).xy));
        float normalWeight = max(pow(max(dot(normal, normalAt), 0.0), 8.0), 0.01);

        float depthAt = texture2D(depthtex0, prevTexCoords).r;
        float depth = texture2D(depthtex0, texCoords).r;

        vec3 worldAt = screenToWorld(depthAt, prevTexCoords, gbufferPreviousProjection, gbufferPreviousModelView);
        vec3 world = screenToWorld(depth, texCoords, gbufferProjection, gbufferModelView);
        float posWeight = 1.0 / max(pow(30.0, distance(world, worldAt)), EPS);

        float screenWeight = float(clamp(prevTexCoords, 0.0, 1.0) == prevTexCoords);
        float totalWeight = clamp((posWeight + normalWeight) * screenWeight, 0.0, 1.0);

        return mix(currColor, prevColor, TAA_STRENGTH * totalWeight);
    }
#endif

void main() {
    vec3 globalIllumination = vec3(0.0);
    float ambientOcclusion = 1.0;

    if(!isSky(texCoords)) {
        #if GI == 1
            //float F0 = texture2D(colortex2, texCoords).g;
            //bool isMetal = F0 * 255.0 > 229.5;

            #if GI_FILTER == 1
                vec3 scaledViewPos = getViewPos(texCoords * GI_RESOLUTION);
                vec3 scaledNormal = normalize(decodeNormal(texture2D(colortex1, texCoords * GI_RESOLUTION).xy));

                globalIllumination = gaussianFilter(texCoords * GI_RESOLUTION, scaledViewPos, scaledNormal, colortex5, vec2(1.0, 0.0)).rgb;
            #else
                globalIllumination = texture2D(colortex5, texCoords * GI_RESOLUTION).rgb;
            #endif

            #if GI_TEMPORAL_ACCUMULATION == 1
                vec3 fullResNormal = normalize(decodeNormal(texture2D(colortex1, texCoords).xy));
                globalIllumination = clamp(temporalAccumulation(colortex6, globalIllumination, fullResNormal), 0.0, 1.0);
            #endif
        #else 
            #if AO == 1
                ambientOcclusion = texture2D(colortex5, texCoords).a;

                #if AO_FILTER == 1
                    ambientOcclusion = qualityBlur(texCoords, colortex5, viewSize, 7.0, 5.0, 8.0).a;
                #endif
            #endif
        #endif
    }

    /*DRAWBUFFERS:6*/
    gl_FragData[0] = vec4(globalIllumination, ambientOcclusion);
}
