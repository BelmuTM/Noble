/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 0,4 */

layout (location = 0) out vec3 color;
layout (location = 1) out vec3 reflections;

#include "/include/fragment/brdf.glsl"

#include "/include/atmospherics/celestial.glsl"

#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/reflections.glsl"
#include "/include/fragment/atrous.glsl"

void main() {
    #if GI == 0
        color = texture(colortex0, texCoords).rgb;

        #if REFLECTIONS == 1
            if(clamp(texCoords, vec2(0.0), vec2(REFLECTIONS_RES + 1e-3)) == texCoords) {
                vec2 scaledUv  = texCoords * (1.0 / REFLECTIONS_RES);

                vec3 viewPos = getViewPos0(scaledUv);
                Material mat = getMaterial(scaledUv);
                    
                #if REFLECTIONS_TYPE == 1
                    reflections = roughReflections(viewPos, mat);
                #else
                    reflections = simpleReflections(viewPos, mat);
                #endif
            }
        #endif
    #else
        #if GI_FILTER == 0
            color = texture(colortex0, texCoords).rgb;
        #else
            aTrousFilter(color, colortex0, texCoords, 2);
        #endif
    #endif
}
