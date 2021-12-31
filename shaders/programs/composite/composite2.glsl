/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:59 */

layout (location = 0) out vec4 color;
layout (location = 1) out vec4 specCol;

#include "/include/atmospherics/celestial.glsl"
#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/reflections.glsl"
#include "/include/fragment/svgf.glsl"

void main() {
    #if GI == 0
        #if REFLECTIONS == 1
            float resolution = REFLECTIONS_TYPE == 1 ? ROUGH_REFLECT_RES : 1.0;
            vec2 scaledUv = texCoords * (1.0 / resolution);
        
            if(clamp(texCoords, vec2(0.0), vec2(resolution + 1e-3)) == texCoords) {
                vec3 posAt   = getViewPos0(scaledUv);
                material mat = getMaterial(scaledUv);

                specCol.rgb = getSpecularColor(mat.F0, texture(colortex4, scaledUv).rgb);
                specCol.a   = 1.0;
                    
                #if REFLECTIONS_TYPE == 1
                    color.rgb = prefilteredReflections(scaledUv, posAt, mat.normal, pow2(mat.rough), specCol.rgb, mat.isMetal);
                #else
                    float NdotV = maxEps(dot(mat.normal, -normalize(posAt)));
                    color.rgb = simpleReflections(scaledUv, posAt, mat.normal, NdotV, specCol.rgb, mat.isMetal);
                #endif
            }
        #endif
    #else
        if(!isSky(texCoords)) {

            vec2 scaledUv = texCoords * GI_RESOLUTION; 
            #if GI_FILTER == 1
                vec3 scaledViewPos = getViewPos0(scaledUv);
                vec3 scaledNormal  = normalize(decodeNormal(texture(colortex1, scaledUv).xy));

                color.rgb = SVGF(scaledUv, colortex0, scaledViewPos, scaledNormal, 1.5, 3);
            #endif
        }
        color.a = 1.0;
    #endif
}
