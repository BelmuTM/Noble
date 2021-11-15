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
    bool sky = isSky(texCoords);

    if(!sky) {
        vec3 viewPos = getViewPos(texCoords);
        vec3 normal = normalize(decodeNormal(texture(colortex1, texCoords).xy));

        #if GI == 1
            #if GI_FILTER == 1                
                Result.rgb = SVGF(colortex5, viewPos, normal, texCoords);
            #else
                Result.rgb = texture(colortex5, texCoords).rgb;
            #endif
        #else

            #if SSR == 1
                float resolution = SSR_TYPE == 1 ? ROUGH_REFLECT_RES : 1.0;
                float NdotV = max(EPS, dot(normal, -normalize(viewPos)));
                vec3 specularColor = texture(colortex4, texCoords * resolution).rgb;
            
                vec3 reflections = texture(colortex5, texCoords * resolution).rgb;
                vec3 DFG = envBRDFApprox(specularColor, texture(colortex2, texCoords).r, NdotV);
                Result.rgb = mix(Result.rgb, clamp01(reflections), DFG);
            #endif
        #endif
    }

    #if VL == 1
        Result.rgb += VL_FILTER == 1 ? boxBlur(texCoords, colortex8, 2).rgb : texture(colortex8, texCoords).rgb;
    #endif

    vec3 brightSpots;
    #if BLOOM == 1
        brightSpots = luminance(Result.rgb) > BLOOM_LUMA_THRESHOLD ? Result.rgb : vec3(0.0);
    #endif

    /*DRAWBUFFERS:05*/
    gl_FragData[0] = Result;
    gl_FragData[1] = vec4(brightSpots, 1.0);
}
