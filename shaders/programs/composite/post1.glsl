/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:03 */

layout (location = 0) out vec4 color;
layout (location = 1) out vec4 historyBuffer;

#include "/include/utility/blur.glsl"
#include "/include/post/taa.glsl"
#include "/include/post/exposure.glsl"

void main() {
    #if TAA == 1
        color.rgb = clamp16(temporalAntiAliasing(colortex0, colortex3));
    #endif

    float avgLuminance = 0.0;
    #if EXPOSURE == 1
        avgLuminance = computeAverageLuminance(colortex3);
    #endif

    historyBuffer = vec4(color.rgb, avgLuminance);
}
