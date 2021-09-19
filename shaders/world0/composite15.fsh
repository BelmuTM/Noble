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
#include "/lib/util/color.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/post/taa.glsl"
#include "/lib/post/exposure.glsl"

/*
const bool colortex0MipmapEnabled = true;
const int colortex3Format = RGB16F;
const bool colortex3Clear = false;
const bool colortex7Clear = false;
*/

void main() {
    vec4 Result = texture2D(colortex0, texCoords);

    #if TAA == 1
        Result.rgb = saturate(computeTAA(colortex0, colortex3));
    #endif

    float exposureLuma = 1.0;
    #if AUTO_EXPOSURE == 1
        exposureLuma = getExposureLuma(colortex7);
    #endif

    /*DRAWBUFFERS:037*/
    gl_FragData[0] = Result;
    gl_FragData[1] = Result;
    gl_FragData[2] = vec4(exposureLuma);
}
