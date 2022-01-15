/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:4 */

layout (location = 0) out vec4 color;

#include "/include/fragment/filter.glsl"

void main() {
    #if GI == 1
        if(!isSky(texCoords)) {
            #if GI_FILTER == 1
                vec3 viewPos = getViewPos0(texCoords);
                material mat = getMaterial(texCoords);

                color.rgb = SVGF(texCoords, colortex4, viewPos, mat.normal, 1.5, 4);
            #endif
        }
    #endif
}
