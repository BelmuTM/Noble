/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 0 */

layout (location = 0) out vec4 color;

#include "/include/fragment/atrous.glsl"

void main() {
    color = texture(colortex0, texCoords);

    #if GI == 1 && GI_FILTER == 1
        aTrousFilter(color.rgb, colortex0, texCoords, 1);
    #endif
}
