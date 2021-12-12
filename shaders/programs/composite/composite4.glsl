/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/atmospherics/celestial.glsl"
#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/reflections.glsl"
#include "/include/fragment/svgf.glsl"

void main() {
    vec4 color = texture(colortex0, texCoords);
    vec3 outColor = vec3(0.0), specularColor = vec3(0.0);

    #if REFLECTIONS == 1
        #if GI == 0
            float resolution = REFLECTIONS_TYPE == 1 ? ROUGH_REFLECT_RES : 1.0;
            vec2 scaledUv = texCoords * (1.0 / resolution);
        
            if(clamp(texCoords, vec2(0.0), vec2(resolution + 1e-3)) == texCoords) {
                vec3 posAt    = getViewPos0(scaledUv);
                material mat  = getMaterial(scaledUv);
                specularColor = getSpecularColor(mat.F0, texture(colortex4, scaledUv).rgb);
                    
                #if REFLECTIONS_TYPE == 1
                    outColor = prefilteredReflections(scaledUv, posAt, mat.normal, pow2(mat.rough), specularColor, mat.isMetal);
                #else
                    float NdotV = maxEps(dot(mat.normal, -normalize(posAt)));
                    outColor = simpleReflections(scaledUv, posAt, mat.normal, NdotV, specularColor, mat.isMetal);
                #endif
            }
        #endif
    #endif

    #if GI == 1
        if(!isSky(texCoords)) {
            #if GI_FILTER == 1
                vec3 viewPos = getViewPos0(texCoords);
                vec3 normal  = normalize(decodeNormal(texture(colortex1, texCoords).xy));

                outColor = SVGF(colortex5, viewPos, normal, texCoords);
            #endif
        }
    #endif

    /*DRAWBUFFERS:095*/
    gl_FragData[0] = color;
    gl_FragData[1] = vec4(specularColor, 1.0);
    gl_FragData[2] = vec4(outColor, 1.0);
}
