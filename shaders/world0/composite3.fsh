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

vec3 temporalAccumulation(sampler2D prevTex, vec3 currColor, vec3 normal) {
    vec2 prevTexCoords = reprojection(vec3(texCoords, texture2D(depthtex1, texCoords).r));
    vec3 prevColor = texture2D(prevTex, prevTexCoords).rgb;
    prevColor = neighbourhoodClipping(prevTex, prevColor);

    vec3 normalAt = normalize(decodeNormal(texture2D(colortex1, prevTexCoords).xy));

    float normalWeight = max(pow(max(dot(normal, normalAt), 0.0), 8.0), EPS);
    float screenWeight = float(clamp(prevTexCoords, 0.0, 1.0) == prevTexCoords);

    float totalWeight = clamp(normalWeight * screenWeight, 0.0, 1.0);
    return mix(currColor, prevColor, 0.92 * totalWeight);
}

void main() {
    vec3 globalIllumination = vec3(0.0);
    float ambientOcclusion = 1.0;

    #if GI == 1
        vec3 normal = normalize(decodeNormal(texture2D(colortex1, texCoords).xy));
    
        float F0 = texture2D(colortex2, texCoords).g;
        bool isMetal = F0 * 255.0 > 229.5;

        if(!isMetal) {
            #if GI_FILTER == 1
                vec3 viewPos = getViewPos(texCoords);
                globalIllumination = edgeAwareSpatialDenoiser(texCoords * GI_RESOLUTION, viewPos, normal, colortex5, GI_FILTER_SIZE, GI_FILTER_QUALITY, 10.0).rgb;
            #else
                globalIllumination = texture2D(colortex5, texCoords * GI_RESOLUTION).rgb;
            #endif

            #if GI_TEMPORAL_ACCUMULATION == 1
                globalIllumination = clamp(temporalAccumulation(colortex6, globalIllumination, normal), 0.0, 1.0);
            #endif
        }
    #else 
        #if AO == 1
            ambientOcclusion = texture2D(colortex5, texCoords).a;

            #if AO_FILTER == 1
                ambientOcclusion = qualityBlur(texCoords, colortex5, viewSize, 7.0, 5.0, 8.0).a;
            #endif
        #endif
    #endif

    /*DRAWBUFFERS:6*/
    gl_FragData[0] = vec4(globalIllumination, ambientOcclusion);
}
