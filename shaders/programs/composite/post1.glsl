/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 0,8 */

layout (location = 0) out vec3 color;
layout (location = 1) out vec4 historyBuffer;

#include "/include/utility/blur.glsl"
#include "/include/post/taa.glsl"
#include "/include/post/exposure.glsl"

void main() {
    color = texture(colortex0, texCoords).rgb;

    #if TAA == 1 && ACCUMULATION_VELOCITY_WEIGHT == 0
        color = clamp16(temporalAntiAliasing(getMaterial(texCoords), colortex0, colortex8));
    #endif

    float avgLuminance = 0.0;
    #if EXPOSURE == 1
        avgLuminance = computeAverageLuminance(colortex8);
    #endif

    historyBuffer = vec4(color, avgLuminance);
}
