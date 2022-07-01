/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 5,8 */

layout (location = 0) out vec3 color;
layout (location = 1) out vec4 historyBuffer;

#include "/include/utility/blur.glsl"
#include "/include/post/taa.glsl"
#include "/include/post/exposure.glsl"

void main() {
    color = texture(colortex5, texCoords).rgb;

    #if TAA == 1
        color = max0(temporalAntiAliasing(getMaterial(texCoords), colortex5, colortex8));
    #endif

    historyBuffer.rgb = color;

    #if EXPOSURE == 1
        historyBuffer.a = computeAverageLuminance(colortex8);
    #endif
}
