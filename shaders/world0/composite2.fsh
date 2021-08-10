/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 400 compatibility

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

vec3 temporalAccumulation(sampler2D tex, vec3 currColor) {
    vec2 prevTexCoords = reprojection(vec3(texCoords, texture2D(depthtex1, texCoords).r));
    vec3 prevColor = texture2D(tex, prevTexCoords).rgb;
    prevColor = neighbourhoodClamping(tex, prevColor);

    vec2 velocity = (texCoords - prevTexCoords) * viewSize;
    float blendFactor = exp(-length(velocity)) * 0.6 + 0.3;
          blendFactor = clamp(blendFactor + 0.4, EPS, 0.979);
          blendFactor *= float(clamp(prevTexCoords, 0.0, 1.0) == prevTexCoords);

    return mix(currColor, prevColor, blendFactor); 
}

void main() {
    vec3 globalIllumination = vec3(0.0);
    #if GI == 1
        globalIllumination = texture2D(colortex5, texCoords * GI_RESOLUTION).rgb;

        #if GI_TEMPORAL_ACCUMULATION == 1
            globalIllumination = temporalAccumulation(colortex6, globalIllumination);
        #endif
    #endif

    /*DRAWBUFFERS:6*/
    gl_FragData[0] = vec4(globalIllumination, 1.0);
}
