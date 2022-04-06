/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 5,12 */

layout (location = 0) out vec4 color;
layout (location = 1) out vec3 moments;

#include "/include/fragment/atrous.glsl"

void main() {
    color = texture(colortex5, texCoords);

    #if GI == 1 && GI_FILTER == 1
        aTrousFilter(color.rgb, colortex5, texCoords, moments, 1);
    #endif
}
