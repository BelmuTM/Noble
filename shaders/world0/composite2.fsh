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
#include "/lib/frag/dither.glsl"
#include "/lib/frag/noise.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/post/taa.glsl"

/*
const int colortex6Format = RGBA16F;
*/
const bool colortex6Clear = false;

void main() {
    /* Upscaling Global Illumination */
    vec3 GlobalIllumination = vec3(0.0);
    #if GI == 1
        GlobalIllumination = texture2D(colortex5, texCoords * GI_RESOLUTION).rgb;

        #if GI_TEMPORAL_ACCUMULATION == 1
            GlobalIllumination = TAA(colortex6, GlobalIllumination);
        #endif
    #endif

    /*DRAWBUFFERS:6*/
    gl_FragData[0] = vec4(GlobalIllumination, 1.0);
}
