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

void main() {
    vec3 globalIllumination = vec3(0.0);
    #if GI == 1
        globalIllumination = texture2D(colortex5, texCoords * GI_RESOLUTION).rgb;

        #if GI_FILTER == 1
            vec3 viewPos = getViewPos();
            vec3 normal = normalize(decodeNormal(texture2D(colortex1, texCoords).xy));

            globalIllumination = spatialDenoiser(viewPos, normal, colortex5, 
            viewSize * GI_FILTER_RES, GI_FILTER_SIZE, GI_FILTER_QUALITY, 13.0).rgb;
        #endif

        #if GI_TEMPORAL_ACCUMULATION == 1
            globalIllumination = computeTAA(colortex6, globalIllumination);
        #endif
    #endif

    /*DRAWBUFFERS:6*/
    gl_FragData[0] = vec4(globalIllumination, 1.0);
}
