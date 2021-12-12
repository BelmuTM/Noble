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

void main() {
    vec4 color = texture(colortex0, texCoords);

    #if TAA == 1
        color.rgb = clamp16(temporalAntiAliasing(colortex0, colortex3));
    #endif

    float avgLuminance = 0.0;
    #if EXPOSURE == 1
        avgLuminance = computeAverageLuminance(colortex3);
    #endif
    
    /*DRAWBUFFERS:03*/
    gl_FragData[0] = color;
    gl_FragData[1] = vec4(color.rgb, avgLuminance);
}
