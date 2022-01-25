/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:4 */

layout (location = 0) out vec4 color;

#include "/include/atmospherics/celestial.glsl"
#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/reflections.glsl"
#include "/include/fragment/filter.glsl"

void main() {
    #if GI == 0
        #if REFLECTIONS == 1
            vec2 scaledUv  = texCoords * (1.0 / REFLECTIONS_RES);
            vec3 shadowmap = texture(colortex3, texCoords).rgb;
        
            if(clamp(texCoords, vec2(0.0), vec2(REFLECTIONS_RES + 1e-3)) == texCoords) {
                vec3 viewPos0 = getViewPos0(scaledUv);
                vec3 viewPos1 = getViewPos1(scaledUv);

                material mat      = getMaterial(scaledUv);
                material transMat = getMaterialTranslucents(scaledUv);

                if(viewPos0.z != viewPos1.z) mat = transMat;

                vec3 metalF0 = getMetalF0(mat.F0, mat.albedo);
                    
                #if REFLECTIONS_TYPE == 1
                    color.rgb = roughReflections(scaledUv, viewPos0, mat, metalF0);
                #else
                    color.rgb = simpleReflections(scaledUv, viewPos0, mat, metalF0);
                #endif
            }
        #endif
    #else
        if(!isSky(texCoords)) {

            vec2 scaledUv = texCoords * GI_RESOLUTION; 
            #if GI_FILTER == 1
                vec3 scaledViewPos = getViewPos0(scaledUv);
                material scaledMat = getMaterial(scaledUv);

                color.rgb = SVGF(scaledUv, colortex0, scaledViewPos, scaledMat.normal, 1.5, 4);
            #endif
        }
    #endif
}
