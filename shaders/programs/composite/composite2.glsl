/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 4 */

layout (location = 0) out vec4 color;

#include "/include/atmospherics/celestial.glsl"
#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/reflections.glsl"

void main() {
    #if GI == 0
        #if REFLECTIONS == 1
            vec2 scaledUv  = texCoords * (1.0 / REFLECTIONS_RES);
        
            if(clamp(texCoords, vec2(0.0), vec2(REFLECTIONS_RES + 1e-3)) == texCoords) {
                vec3 viewPos = getViewPos0(scaledUv);
                Material mat = getMaterial(scaledUv);
                    
                #if REFLECTIONS_TYPE == 1
                    color.rgb = roughReflections(scaledUv, viewPos, mat);
                #else
                    color.rgb = simpleReflections(scaledUv, viewPos, mat);
                #endif
            }
        #endif
    #endif
}
