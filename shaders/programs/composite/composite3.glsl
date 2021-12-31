/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:5 */

layout (location = 0) out vec4 color;

#include "/include/fragment/svgf.glsl"

void main() {
    #if GI == 1
        if(!isSky(texCoords)) {
            #if GI_FILTER == 1
                vec3 viewPos = getViewPos0(texCoords);
                vec3 normal  = normalize(decodeNormal(texture(colortex1, texCoords).xy));

                color.rgb = SVGF(texCoords, colortex5, viewPos, normal, 1.5, 4);
            #endif
        }
    #endif
}
