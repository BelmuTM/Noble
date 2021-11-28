/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/utility/blur.glsl"
#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/ssr.glsl"
#include "/include/fragment/svgf.glsl"

void main() {
    vec4 Result = texture(colortex0, texCoords);
    vec3 outColor = vec3(0.0), specularColor = vec3(0.0);

    #if SSR == 1
        #if GI == 0
            float resolution = SSR_TYPE == 1 ? ROUGH_REFLECT_RES : 1.0;
            vec2 scaledUv = texCoords * (1.0 / resolution);
        
            if(clamp(texCoords, vec2(0.0), vec2(resolution + 1e-3)) == texCoords && !isSky(scaledUv)) {
                vec3 posAt = getViewPos(scaledUv);
                material mat = getMaterial(scaledUv);
                specularColor = getSpecularColor(mat.F0, texture(colortex4, scaledUv).rgb);
                    
                #if SSR_TYPE == 1
                    outColor = prefilteredReflections(scaledUv, posAt, mat.normal, pow2(mat.rough), specularColor, mat.isMetal);
                #else
                    float NdotV = maxEps(dot(mat.normal, -normalize(posAt)));
                    outColor = simpleReflections(scaledUv, posAt, mat.normal, NdotV, specularColor, mat.isMetal);
                #endif
            }
        #endif
    #endif

    if(!isSky(texCoords)) {
        #if GI == 1
            #if GI_FILTER == 1
                vec3 viewPos = getViewPos(texCoords);
                vec3 normal = normalize(decodeNormal(texture(colortex1, texCoords).xy));

                outColor = SVGF(colortex5, viewPos, normal, texCoords);
            #else
                outColor = texture(colortex5, texCoords).rgb;
            #endif
        #else
            #if AO == 1
                #if AO_TYPE == 0
                    #if SSAO_FILTER == 1
                        bool isMetal = texture(colortex2, texCoords).g * 255.0 > 229.5;
                        Result.rgb *= isMetal ? 1.0 : gaussianBlur(texCoords, colortex5, vec2(0.0, 1.0), 1.0).a;
                    #endif
                #endif
            #endif
        #endif
    }

    /*DRAWBUFFERS:095*/
    gl_FragData[0] = Result;
    gl_FragData[1] = vec4(specularColor, 1.0);
    gl_FragData[2] = vec4(outColor, 1.0);
}
