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

            vec2 scaledUv = texCoords * GI_RESOLUTION; 
            #if GI_FILTER == 1
                vec3 scaledViewPos = getViewPos0(scaledUv);
                material scaledMat = getMaterial(scaledUv);

                color.rgb = SVGF(scaledUv, colortex0, scaledViewPos, scaledMat.normal, 1.5, 3);
            #endif
        }
    #endif
}
