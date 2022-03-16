/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 0 */

layout (location = 0) out vec3 color;

#include "/include/fragment/atrous.glsl"

void main() {
    #if GI == 0
        color = texture(colortex0, texCoords).rgb;
    #else
        #if GI_FILTER == 0
            color = texture(colortex0, texCoords).rgb;
        #else
            aTrousFilter(color, colortex0, texCoords, 1);
        #endif
    #endif
}
