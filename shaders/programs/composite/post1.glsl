/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/utility/blur.glsl"
#include "/include/post/taa.glsl"
#include "/include/post/exposure.glsl"

/*
const int colortex3Format = RGBA16F;
const bool colortex3Clear = false;
*/

void main() {
    vec4 Result = texture(colortex0, texCoords);

    #if TAA == 1
        Result.rgb = max0(temporalAntiAliasing(colortex0, colortex3));
    #endif
    
    /*DRAWBUFFERS:03*/
    gl_FragData[0] = Result;
    gl_FragData[1] = vec4(Result.rgb, computeAverageLuminance(colortex3));
}
