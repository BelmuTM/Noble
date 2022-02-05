/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:04 */

layout (location = 0) out vec4 color;
layout (location = 1) out vec4 filtered;

#include "/include/fragment/filter.glsl"

void main() {
    color = texture(colortex0, texCoords);

    #if GI == 1
        if(!isSky(texCoords)) {
            vec2 scaledUv = texCoords * GI_RESOLUTION; 

            #if GI_FILTER == 1
                vec3 scaledViewPos = getViewPos0(scaledUv);
                Material scaledMat = getMaterial(scaledUv);

                filtered.rgb = SVGF(scaledUv, colortex0, scaledViewPos, scaledMat.normal, 1.5, 3);
            #else
                color = texture(colortex0, scaledUv);
            #endif
        }
    #endif
}
